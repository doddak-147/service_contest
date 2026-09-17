import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../market_risk/presentation/market_risk_screen.dart';
import '../../stress_test/models/stress_test_models.dart';
import '../../stress_test/presentation/stress_test_screen.dart';
import '../data/financial_health_api.dart';
import '../models/financial_health_models.dart';
import 'widgets/financial_health_result_card.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen> {
  // API_CONTRACT.md의 예시값을 기본값으로 두면 팀원이 앱을 켠 즉시 검산할 수 있다.
  final _monthlyIncomeController = TextEditingController(text: '3000000');
  final _monthlyFixedExpensesController = TextEditingController(
    text: '1500000',
  );
  final _emergencyFundController = TextEditingController(text: '5000000');
  final _existingLoanBalanceController = TextEditingController(
    text: '10000000',
  );
  final _monthlyDebtPaymentController = TextEditingController(text: '400000');
  final _plannedInvestmentController = TextEditingController(text: '10000000');
  final _equityAmountController = TextEditingController(text: '6000000');
  final _borrowedAmountController = TextEditingController(text: '4000000');
  final _annualLoanRateController = TextEditingController(text: '6');

  late final FinancialHealthApi _financialHealthApi;
  FinancialHealthResult? _result;
  FinancialProfileInput? _analyzedProfile;
  String? _errorMessage;
  bool _isLoading = false;
  int _requestId = 0;

  static const _fieldLabels = {
    'monthly_income_krw': '월 소득',
    'monthly_fixed_expenses_krw': '월 고정지출',
    'emergency_fund_krw': '비상자금',
    'existing_loan_balance_krw': '기존 대출 잔액',
    'monthly_debt_payment_krw': '기존 월 대출 상환액',
    'planned_investment_krw': '총 투자 예정금액',
    'equity_amount_krw': '자기자본',
    'borrowed_amount_krw': '투자용 차입금',
    'annual_loan_rate': '투자용 차입금 연이율',
  };

  @override
  void initState() {
    super.initState();
    _financialHealthApi = FinancialHealthApi(widget.apiClient);
  }

  @override
  void dispose() {
    _monthlyIncomeController.dispose();
    _monthlyFixedExpensesController.dispose();
    _emergencyFundController.dispose();
    _existingLoanBalanceController.dispose();
    _monthlyDebtPaymentController.dispose();
    _plannedInvestmentController.dispose();
    _equityAmountController.dispose();
    _borrowedAmountController.dispose();
    _annualLoanRateController.dispose();
    super.dispose();
  }

  int _parseInteger(TextEditingController controller, String label) {
    final normalized = controller.text.replaceAll(',', '').trim();
    final value = int.tryParse(normalized);
    if (normalized.isEmpty || value == null) {
      throw FormatException('$label을(를) 원 단위 정수로 입력해 주세요.');
    }
    return value;
  }

  double _parseAnnualRate() {
    final rawValue = _annualLoanRateController.text.trim();
    final percent = double.tryParse(rawValue);
    if (rawValue.isEmpty || percent == null || !percent.isFinite) {
      throw const FormatException('투자용 차입금 연이율을 숫자로 입력해 주세요.');
    }

    // 화면에서는 사람이 읽기 쉬운 %를 받고 API 계약에는 0..1 비율로 전송한다.
    return percent / 100;
  }

  FinancialProfileInput _buildProfile() {
    return FinancialProfileInput(
      monthly_income_krw: _parseInteger(_monthlyIncomeController, '월 소득'),
      monthly_fixed_expenses_krw: _parseInteger(
        _monthlyFixedExpensesController,
        '월 고정지출',
      ),
      emergency_fund_krw: _parseInteger(_emergencyFundController, '비상자금'),
      existing_loan_balance_krw: _parseInteger(
        _existingLoanBalanceController,
        '기존 대출 잔액',
      ),
      monthly_debt_payment_krw: _parseInteger(
        _monthlyDebtPaymentController,
        '기존 월 대출 상환액',
      ),
      planned_investment_krw: _parseInteger(
        _plannedInvestmentController,
        '총 투자 예정금액',
      ),
      equity_amount_krw: _parseInteger(_equityAmountController, '자기자본'),
      borrowed_amount_krw: _parseInteger(_borrowedAmountController, '투자용 차입금'),
      annual_loan_rate: _parseAnnualRate(),
    );
  }

  void _clearResultOnEdit(String _) {
    _requestId++;
    if (_result != null || _errorMessage != null || _isLoading) {
      setState(() {
        _result = null;
        _analyzedProfile = null;
        _errorMessage = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _analyze() async {
    final requestId = ++_requestId;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // 금융 계산은 서버가 담당한다. Flutter는 입력 전송과 결과 표시만 수행한다.
      final profile = _buildProfile();
      final result = await _financialHealthApi.analyze(profile);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _result = result;
        _analyzedProfile = profile;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _result = null;
        _analyzedProfile = null;
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException && error.fieldErrors.isNotEmpty) {
      final fieldError = error.fieldErrors.first;
      final label = _fieldLabels[fieldError.field] ?? '입력값';
      return switch (fieldError.reason) {
        'INVESTMENT_SUM_MISMATCH' => '자기자본과 투자용 차입금의 합이 총 투자 예정금액과 같아야 합니다.',
        'MUST_BE_GREATER_THAN_ZERO' => '$label은(는) 0보다 커야 합니다.',
        'MUST_BE_NON_NEGATIVE' => '$label은(는) 음수일 수 없습니다.',
        'RATE_OUT_OF_RANGE' => '투자용 차입금 연이율은 0% 이상 100% 이하로 입력해 주세요.',
        _ => error.message,
      };
    }
    if (error is ApiException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return '금융체력 분석 요청에 실패했습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인 금융체력 분석')),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Text(
              '개인 금융체력 분석',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '현재 재무상태와 투자 계획을 함께 입력해 월 현금흐름, 비상자금 '
              '버팀 기간, 투자금 차입 비율을 확인합니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              number: '1',
              title: '재무정보 입력',
              description: '금액은 원 단위로 입력하세요. 입력값은 서버에 저장하지 않습니다.',
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _InputField(
                      controller: _monthlyIncomeController,
                      hint: '세후 기준, 원',
                      label: '월 소득',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _monthlyFixedExpensesController,
                      hint: '주거비·생활비 등 필수 고정지출, 원',
                      label: '월 고정지출',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _emergencyFundController,
                      hint: '즉시 사용할 수 있는 현금성 자금, 원',
                      label: '비상자금',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _existingLoanBalanceController,
                      hint: '투자용 차입 전 기존 대출 잔액, 원',
                      label: '기존 대출 잔액',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _monthlyDebtPaymentController,
                      hint: '기존 대출의 월 상환액, 원',
                      label: '기존 월 대출 상환액',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _plannedInvestmentController,
                      hint: '자기자본 + 투자용 차입금, 원',
                      label: '총 투자 예정금액',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _equityAmountController,
                      hint: '투자금 중 본인 자금, 원',
                      label: '자기자본',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _borrowedAmountController,
                      hint: '투자를 위해 새로 빌릴 금액, 원',
                      label: '투자용 차입금',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      allowDecimal: true,
                      controller: _annualLoanRateController,
                      hint: '% 단위로 입력',
                      label: '투자용 차입금 연이율',
                      onChanged: _clearResultOnEdit,
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.dangerBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _analyze,
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.surface,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('금융체력 계산하기'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 32),
              const _SectionHeading(
                number: '2',
                title: '금융체력 결과',
                description: '안전 점수 대신 서버가 계산한 객관적인 재무 지표를 보여줍니다.',
              ),
              const SizedBox(height: 16),
              FinancialHealthResultCard(result: _result!),
              if (_analyzedProfile != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StressTestScreen(
                          apiClient: widget.apiClient,
                          initialProfile: _analyzedProfile,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('이 정보로 Stress Test 진행'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MarketRiskScreen(
                          apiClient: widget.apiClient,
                          financialProfile: _analyzedProfile,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('종목 선택 후 결합 Report 만들기'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.label,
    required this.onChanged,
    this.allowDecimal = false,
  });

  final bool allowDecimal;
  final TextEditingController controller;
  final String hint;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(allowDecimal ? r'[-0-9.]' : r'[-0-9,]'),
          ),
        ],
        keyboardType: TextInputType.numberWithOptions(
          decimal: allowDecimal,
          signed: true,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(helperText: hint, labelText: label),
      ),
    );
  }
}
