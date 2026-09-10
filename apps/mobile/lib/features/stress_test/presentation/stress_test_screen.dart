import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/stress_test_api.dart';
import '../models/stress_test_models.dart';
import 'widgets/stress_test_result_card.dart';

class StressTestScreen extends StatefulWidget {
  const StressTestScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  final _monthlyIncomeController = TextEditingController(text: '3000000');
  final _monthlyFixedExpensesController = TextEditingController(
    text: '1800000',
  );
  final _plannedInvestmentController = TextEditingController(text: '15000000');
  final _equityAmountController = TextEditingController(text: '5000000');
  final _borrowedAmountController = TextEditingController(text: '10000000');
  final _annualLoanRateController = TextEditingController(text: '6');

  late final StressTestApi _stressTestApi;
  String _selectedScenario = ScenarioKeys.down20;
  List<ScenarioResult> _results = const [];
  String? _errorMessage;
  bool _isLoading = false;

  static const _scenarioLabels = {
    ScenarioKeys.down10: '-10%',
    ScenarioKeys.down20: '-20%',
    ScenarioKeys.down30: '-30%',
    ScenarioKeys.down40: '-40%',
    ScenarioKeys.down50: '-50%',
  };

  static const _fieldLabels = {
    'monthly_income_krw': '월 소득',
    'monthly_fixed_expenses_krw': '월 고정지출',
    'planned_investment_krw': '총 투자 예정금액',
    'equity_amount_krw': '자기자본',
    'borrowed_amount_krw': '차입금',
    'annual_loan_rate': '차입금 연이율',
  };

  @override
  void initState() {
    super.initState();
    _stressTestApi = StressTestApi(widget.apiClient);
  }

  @override
  void dispose() {
    _monthlyIncomeController.dispose();
    _monthlyFixedExpensesController.dispose();
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
      throw const FormatException('차입금 연이율을 숫자로 입력해 주세요.');
    }
    return percent / 100;
  }

  StressTestRequest _buildRequest() {
    return StressTestRequest(
      financial_profile: FinancialProfileInput(
        monthly_income_krw: _parseInteger(_monthlyIncomeController, '월 소득'),
        monthly_fixed_expenses_krw: _parseInteger(
          _monthlyFixedExpensesController,
          '월 고정지출',
        ),
        emergency_fund_krw: 0,
        existing_loan_balance_krw: 0,
        monthly_debt_payment_krw: 0,
        planned_investment_krw: _parseInteger(
          _plannedInvestmentController,
          '총 투자 예정금액',
        ),
        equity_amount_krw: _parseInteger(_equityAmountController, '자기자본'),
        borrowed_amount_krw: _parseInteger(_borrowedAmountController, '차입금'),
        annual_loan_rate: _parseAnnualRate(),
      ),
      historical_mdd_rate: null,
    );
  }

  void _clearResultOnEdit(String _) {
    if (_results.isNotEmpty || _errorMessage != null) {
      setState(() {
        _results = const [];
        _errorMessage = null;
      });
    }
  }

  Future<void> _analyze() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final results = await _stressTestApi.analyze(_buildRequest());
      if (!mounted) {
        return;
      }
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const [];
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException && error.fieldErrors.isNotEmpty) {
      final fieldError = error.fieldErrors.first;
      final label = _fieldLabels[fieldError.field] ?? '입력값';
      return switch (fieldError.reason) {
        'INVESTMENT_SUM_MISMATCH' => '자기자본과 차입금의 합이 총 투자 예정금액과 같아야 합니다.',
        'MUST_BE_GREATER_THAN_ZERO' => '$label은(는) 0보다 커야 합니다.',
        'MUST_BE_NON_NEGATIVE' => '$label은(는) 음수일 수 없습니다.',
        'RATE_OUT_OF_RANGE' => '차입금 연이율은 0% 이상 100% 이하로 입력해 주세요.',
        _ => error.message,
      };
    }
    if (error is ApiException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return '분석 요청에 실패했습니다.';
  }

  ScenarioResult? get _selectedResult {
    for (final result in _results) {
      if (result.scenario_key == _selectedScenario) {
        return result;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedResult = _selectedResult;
    return Scaffold(
      appBar: AppBar(title: const Text('차입투자 Stress Test')),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Text(
              '차입투자 Stress Test',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '가정한 주가 하락이 현재 투자금과 자기자본에 주는 충격을 확인합니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              number: '1',
              title: '투자정보 입력',
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
                      hint: '주거비·생활비 등, 원',
                      label: '월 고정지출',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      controller: _plannedInvestmentController,
                      hint: '원',
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
                      hint: '투자금 중 빌린 자금, 원',
                      label: '차입금',
                      onChanged: _clearResultOnEdit,
                    ),
                    _InputField(
                      allowDecimal: true,
                      controller: _annualLoanRateController,
                      hint: '% 단위로 입력',
                      label: '차입금 연이율',
                      onChanged: _clearResultOnEdit,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              number: '2',
              title: '하락률 선택',
              description: '분석 후에도 값을 다시 입력하지 않고 결과를 바꿔 볼 수 있습니다.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScenarioKeys.declines
                  .map((scenarioKey) {
                    return ChoiceChip(
                      label: Text(_scenarioLabels[scenarioKey]!),
                      onSelected: (_) {
                        setState(() => _selectedScenario = scenarioKey);
                      },
                      selected: _selectedScenario == scenarioKey,
                      selectedColor: AppColors.dangerBackground,
                      side: BorderSide(
                        color: _selectedScenario == scenarioKey
                            ? AppColors.danger
                            : AppColors.border,
                      ),
                    );
                  })
                  .toList(growable: false),
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
                  : const Text('금융 충격 계산하기'),
            ),
            if (selectedResult != null) ...[
              const SizedBox(height: 32),
              const _SectionHeading(
                number: '3',
                title: 'Stress Test 결과',
                description: '다른 하락률을 누르면 서버가 계산한 해당 결과로 즉시 바뀝니다.',
              ),
              const SizedBox(height: 16),
              StressTestResultCard(result: selectedResult),
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
