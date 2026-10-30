import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/input/krw_input_formatter.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/investment_total_summary.dart';
import '../data/stress_test_api.dart';
import '../models/stress_test_models.dart';
import 'widgets/stress_test_comparison_card.dart';
import 'widgets/leverage_comparison_card.dart';
import 'widgets/scenario_comparison_chart.dart';
import 'widgets/stress_test_result_card.dart';

class StressTestScreen extends StatefulWidget {
  const StressTestScreen({
    required this.apiClient,
    this.initialProfile,
    this.historicalMddRate,
    this.historicalMddSource,
    this.instrumentCurrency,
    this.isExampleProfile = false,
    super.key,
  });

  final ApiClient apiClient;
  final FinancialProfileInput? initialProfile;
  final double? historicalMddRate;
  final String? historicalMddSource;
  final String? instrumentCurrency;
  final bool isExampleProfile;

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  late final TextEditingController _monthlyIncomeController;
  late final TextEditingController _monthlyFixedExpensesController;
  late final TextEditingController _emergencyFundController;
  late final TextEditingController _existingLoanBalanceController;
  late final TextEditingController _monthlyDebtPaymentController;
  late final TextEditingController _equityAmountController;
  late final TextEditingController _borrowedAmountController;
  late final TextEditingController _annualLoanRateController;
  late final TextEditingController _customReturnRateController;

  late final StressTestApi _stressTestApi;
  String _selectedScenario = ScenarioKeys.down20;
  double _selectedFxChangeRate = 0.0;
  List<ScenarioResult> _results = const [];
  List<ScenarioResult> _withoutBorrowingResults = const [];
  FinancialProfileInput? _analyzedProfile;
  String? _comparisonMessage;
  String? _errorMessage;
  bool _isLoading = false;
  int _requestId = 0;

  static const _scenarioLabels = {
    ScenarioKeys.up20: '+20%',
    ScenarioKeys.flat: '보합',
    ScenarioKeys.down10: '-10%',
    ScenarioKeys.down20: '-20%',
    ScenarioKeys.down30: '-30%',
    ScenarioKeys.down40: '-40%',
    ScenarioKeys.down50: '-50%',
    ScenarioKeys.historicalMdd: '과거 MDD',
    ScenarioKeys.custom: '직접 입력',
  };

  static const _fieldLabels = {
    'monthly_income_krw': '월 소득',
    'monthly_fixed_expenses_krw': '월 고정지출',
    'emergency_fund_krw': '비상자금',
    'existing_loan_balance_krw': '기존 대출 잔액',
    'monthly_debt_payment_krw': '기존 월 대출 상환액',
    'planned_investment_krw': '총 투자 예정금액',
    'equity_amount_krw': '자기자본',
    'borrowed_amount_krw': '차입금',
    'annual_loan_rate': '차입금 연이율',
    'exchange_rate_change_rate': '원/달러 환율 변동률',
    'custom_return_rate': '직접 입력 시나리오',
  };

  @override
  void initState() {
    super.initState();
    _stressTestApi = StressTestApi(widget.apiClient);
    final profile = widget.initialProfile;
    _monthlyIncomeController = TextEditingController(
      text: formatKrwInput('${profile?.monthly_income_krw ?? 3000000}'),
    );
    _monthlyFixedExpensesController = TextEditingController(
      text: formatKrwInput('${profile?.monthly_fixed_expenses_krw ?? 1800000}'),
    );
    _emergencyFundController = TextEditingController(
      text: formatKrwInput('${profile?.emergency_fund_krw ?? 5000000}'),
    );
    _existingLoanBalanceController = TextEditingController(
      text: formatKrwInput('${profile?.existing_loan_balance_krw ?? 10000000}'),
    );
    _monthlyDebtPaymentController = TextEditingController(
      text: formatKrwInput('${profile?.monthly_debt_payment_krw ?? 400000}'),
    );
    _equityAmountController = TextEditingController(
      text: formatKrwInput('${profile?.equity_amount_krw ?? 5000000}'),
    );
    _borrowedAmountController = TextEditingController(
      text: formatKrwInput('${profile?.borrowed_amount_krw ?? 10000000}'),
    );
    _annualLoanRateController = TextEditingController(
      text: _formatRateInput(profile?.annual_loan_rate ?? 0.06),
    );
    _customReturnRateController = TextEditingController();
  }

  @override
  void dispose() {
    _monthlyIncomeController.dispose();
    _monthlyFixedExpensesController.dispose();
    _emergencyFundController.dispose();
    _existingLoanBalanceController.dispose();
    _monthlyDebtPaymentController.dispose();
    _equityAmountController.dispose();
    _borrowedAmountController.dispose();
    _annualLoanRateController.dispose();
    _customReturnRateController.dispose();
    super.dispose();
  }

  String _formatRateInput(double rate) {
    final percent = rate * 100;
    return percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(2);
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

  double? _parseCustomReturnRate() {
    final rawValue = _customReturnRateController.text.trim();
    if (rawValue.isEmpty && _selectedScenario != ScenarioKeys.custom) {
      return null;
    }
    final percent = double.tryParse(rawValue);
    if (percent == null ||
        !percent.isFinite ||
        !RegExp(r'^[-+]?\d{1,3}(\.\d{1,2})?$').hasMatch(rawValue) ||
        percent < -100 ||
        percent > 100) {
      throw const FormatException(
        '직접 입력 비율은 -100%부터 +100%까지 소수 둘째 자리 이하로 입력해 주세요.',
      );
    }
    return percent / 100;
  }

  StressTestRequest _buildRequest() {
    final equity = _parseInteger(_equityAmountController, '자기자본');
    final borrowed = _parseInteger(_borrowedAmountController, '차입금');
    return StressTestRequest(
      financial_profile: FinancialProfileInput(
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
        planned_investment_krw: equity + borrowed,
        equity_amount_krw: equity,
        borrowed_amount_krw: borrowed,
        annual_loan_rate: _parseAnnualRate(),
      ),
      historical_mdd_rate: widget.historicalMddRate,
      exchange_rate_change_rate: widget.instrumentCurrency == 'USD'
          ? _selectedFxChangeRate
          : 0.0,
      custom_return_rate: _parseCustomReturnRate(),
    );
  }

  void _clearResultOnEdit(String _) {
    _requestId++;
    if (_results.isNotEmpty || _errorMessage != null || _isLoading) {
      setState(() {
        _results = const [];
        _withoutBorrowingResults = const [];
        _analyzedProfile = null;
        _comparisonMessage = null;
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
      _results = const [];
      _withoutBorrowingResults = const [];
      _analyzedProfile = null;
      _comparisonMessage = null;
    });

    try {
      final request = _buildRequest();
      final profile = request.financial_profile;
      final results = await _stressTestApi.analyze(request);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = results;
        _analyzedProfile = profile;
      });

      if (profile.borrowed_amount_krw == 0) {
        setState(() => _comparisonMessage = '차입금이 0원이므로 두 경우가 같습니다.');
      } else if (profile.equity_amount_krw == 0) {
        setState(
          () => _comparisonMessage =
              '자기자본이 0원이어서 차입 없는 투자금은 0원입니다. 이 경우 비교 시나리오는 계산하지 않습니다.',
        );
      } else {
        final withoutBorrowing = StressTestRequest(
          financial_profile: FinancialProfileInput(
            monthly_income_krw: profile.monthly_income_krw,
            monthly_fixed_expenses_krw: profile.monthly_fixed_expenses_krw,
            emergency_fund_krw: profile.emergency_fund_krw,
            existing_loan_balance_krw: profile.existing_loan_balance_krw,
            monthly_debt_payment_krw: profile.monthly_debt_payment_krw,
            planned_investment_krw: profile.equity_amount_krw,
            equity_amount_krw: profile.equity_amount_krw,
            borrowed_amount_krw: 0,
            annual_loan_rate: profile.annual_loan_rate,
          ),
          historical_mdd_rate: request.historical_mdd_rate,
          exchange_rate_change_rate: request.exchange_rate_change_rate,
          custom_return_rate: request.custom_return_rate,
        );
        try {
          final baselineResults = await _stressTestApi.analyze(
            withoutBorrowing,
          );
          if (!mounted || requestId != _requestId) return;
          setState(() => _withoutBorrowingResults = baselineResults);
        } catch (_) {
          if (!mounted || requestId != _requestId) return;
          setState(
            () => _comparisonMessage =
                '차입 없는 경우의 계산 결과를 불러오지 못했습니다. 기존 Stress Test 결과는 확인할 수 있습니다.',
          );
        }
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = const [];
        _withoutBorrowingResults = const [];
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
        'INVESTMENT_SUM_MISMATCH' => '자기자본과 차입금의 합이 총 투자 예정금액과 같아야 합니다.',
        'MUST_BE_GREATER_THAN_ZERO' => '$label은(는) 0보다 커야 합니다.',
        'MUST_BE_NON_NEGATIVE' => '$label은(는) 음수일 수 없습니다.',
        'RATE_OUT_OF_RANGE' =>
          fieldError.field == 'exchange_rate_change_rate'
              ? '환율 변동률은 -50% 이상 +50% 이하로 선택해 주세요.'
              : fieldError.field == 'custom_return_rate'
              ? '직접 입력 비율은 -100%부터 +100%까지 입력해 주세요.'
              : '차입금 연이율은 0% 이상 100% 이하로 입력해 주세요.',
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

  ScenarioResult? get _selectedWithoutBorrowingResult {
    for (final result in _withoutBorrowingResults) {
      if (result.scenario_key == _selectedScenario) return result;
    }
    return null;
  }

  List<String> get _availableScenarioKeys => [
    ...ScenarioKeys.fixed,
    if (widget.historicalMddRate != null) ScenarioKeys.historicalMdd,
    ScenarioKeys.custom,
  ];

  String _scenarioLabel(String scenarioKey) {
    if (scenarioKey == ScenarioKeys.historicalMdd &&
        widget.historicalMddRate != null) {
      final percent = widget.historicalMddRate! * 100;
      return '과거 MDD (${percent.toStringAsFixed(1)}%)';
    }
    return _scenarioLabels[scenarioKey]!;
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
              '가정한 상승·보합·하락 상황에서 자산과 부채가 어떻게 달라지는지 비교합니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (widget.initialProfile != null) ...[
              const SizedBox(height: 16),
              const _ContextBanner(
                icon: Icons.account_balance_wallet_outlined,
                message: '금융체력 분석에서 사용한 재무정보를 불러왔습니다.',
              ),
            ],
            if (widget.isExampleProfile || widget.initialProfile == null) ...[
              const SizedBox(height: 12),
              const _ContextBanner(
                icon: Icons.science_outlined,
                message: '가상 재무 예시값으로 시작했습니다. 값을 수정했다면 계산 전에 입력 내용을 확인해 주세요.',
              ),
            ],
            if (widget.historicalMddRate != null) ...[
              const SizedBox(height: 12),
              _ContextBanner(
                icon: Icons.show_chart,
                message:
                    '${widget.historicalMddSource ?? '선택한 종목'}의 ${widget.instrumentCurrency == 'USD' ? '최근 3개월 ' : ''}관측 구간 MDD '
                    '${(widget.historicalMddRate! * 100).toStringAsFixed(1)}%를 시나리오에 포함합니다. 전체 과거의 최악을 뜻하지 않습니다.',
              ),
            ],
            if (widget.instrumentCurrency == 'USD') ...[
              const SizedBox(height: 12),
              const _ContextBanner(
                icon: Icons.currency_exchange,
                message:
                    '미국 종목의 투자금은 원화 기준입니다. 주가와 원/달러 환율의 변동을 별도로 가정합니다. 과거 MDD에는 당시 환율 영향이 이미 포함되어 추가 환율 가정을 적용하지 않습니다.',
              ),
            ],
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
                    InvestmentTotalSummary(
                      equityController: _equityAmountController,
                      borrowedController: _borrowedAmountController,
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
              title: '시나리오 선택',
              description: '미래 예측이 아닌 가정입니다. 분석 후 결과를 즉시 바꿔 볼 수 있습니다.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableScenarioKeys
                  .map((scenarioKey) {
                    return ChoiceChip(
                      label: Text(_scenarioLabel(scenarioKey)),
                      onSelected: (_) {
                        setState(() => _selectedScenario = scenarioKey);
                      },
                      selected: _selectedScenario == scenarioKey,
                      selectedColor: scenarioKey == ScenarioKeys.up20
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.dangerBackground,
                      side: BorderSide(
                        color: _selectedScenario == scenarioKey
                            ? scenarioKey == ScenarioKeys.up20
                                  ? AppColors.primary
                                  : AppColors.danger
                            : AppColors.border,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            if (_selectedScenario == ScenarioKeys.custom) ...[
              const SizedBox(height: 16),
              _InputField(
                allowDecimal: true,
                controller: _customReturnRateController,
                hint: '예: -17.5는 17.5% 하락, 12.5는 12.5% 상승 가정',
                label: '직접 입력 변동률',
                onChanged: _clearResultOnEdit,
              ),
              const Text('미래 예측이 아닌 가정입니다. -100%부터 +100%까지 입력할 수 있습니다.'),
            ],
            if (widget.instrumentCurrency == 'USD') ...[
              const SizedBox(height: 20),
              const Text(
                '원/달러 환율 변동 가정',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('환율 하락은 같은 달러 자산의 원화 가치가 줄어드는 경우입니다.'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [-0.1, 0.0, 0.1]
                    .map((rate) {
                      final percent = (rate * 100).round();
                      return ChoiceChip(
                        label: Text(percent > 0 ? '+$percent%' : '$percent%'),
                        selected: _selectedFxChangeRate == rate,
                        onSelected: (_) {
                          final shouldRefresh = _results.isNotEmpty;
                          setState(() => _selectedFxChangeRate = rate);
                          if (shouldRefresh) _analyze();
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              if (_selectedScenario == ScenarioKeys.historicalMdd) ...[
                const SizedBox(height: 8),
                const Text(
                  '과거 MDD는 이미 당시 환율을 반영한 원화 기준입니다. 위 환율 선택은 과거 MDD 결과에는 적용되지 않고 다른 시나리오에만 적용됩니다.',
                ),
              ],
            ],
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
              const SizedBox(height: 28),
              const _SectionHeading(
                number: '4',
                title: '차입 없음 · 차입 있음 비교',
                description: '자기자본과 다른 재무조건은 고정하고, 차입금만 제외해 투자금 규모를 달리한 가정입니다.',
              ),
              const SizedBox(height: 16),
              if (_selectedWithoutBorrowingResult != null &&
                  _analyzedProfile != null)
                LeverageComparisonCard(
                  withoutBorrowing: _selectedWithoutBorrowingResult!,
                  withBorrowing: selectedResult,
                  profile: _analyzedProfile!,
                )
              else
                _ContextBanner(
                  icon: Icons.info_outline,
                  message:
                      _comparisonMessage ??
                      (_isLoading
                          ? '비교 결과를 계산하고 있습니다.'
                          : '선택한 시나리오의 비교 결과가 없습니다.'),
                ),
              const SizedBox(height: 28),
              const _SectionHeading(
                number: '5',
                title: '전체 시나리오 비교',
                description: '같은 재무정보에 각 가정만 바꿔 결과를 비교합니다.',
              ),
              const SizedBox(height: 16),
              ScenarioComparisonChart(results: _results),
              const SizedBox(height: 16),
              StressTestComparisonCard(results: _results),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
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
        inputFormatters: allowDecimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))]
            : const [KrwInputFormatter()],
        keyboardType: TextInputType.numberWithOptions(
          decimal: allowDecimal,
          signed: true,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          helperText: hint,
          labelText: label,
          suffixText: allowDecimal ? '%' : '원',
        ),
      ),
    );
  }
}
