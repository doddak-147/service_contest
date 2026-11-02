import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/api/api_client.dart';
import '../../../shared/input/krw_input_formatter.dart';
import '../../../shared/theme/app_theme.dart';
import '../../offline_demo/offline_demo_data.dart';
import '../../offline_demo/cash_flow_fixtures.dart';
import '../data/cash_flow_api.dart';
import '../models/cash_flow_models.dart';
import '../models/stress_test_models.dart';
import 'widgets/cash_flow_result_view.dart';
import 'widgets/cash_flow_comparison_view.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({
    this.apiClient,
    this.initialProfile,
    this.isExampleProfile = false,
    this.isOfflineDemo = false,
    this.initialCurrency = 'KRW',
    super.key,
  }) : assert(isOfflineDemo || apiClient != null);
  final ApiClient? apiClient;
  final FinancialProfileInput? initialProfile;
  final bool isExampleProfile, isOfflineDemo;
  final String initialCurrency;
  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  static const _profileLabels = {
    'monthly_income_krw': '월 소득',
    'monthly_fixed_expenses_krw': '월 생활비·고정지출',
    'emergency_fund_krw': '투자 후 별도로 남겨 둔 비상자금',
    'existing_loan_balance_krw': '기존 대출 잔액',
    'monthly_debt_payment_krw': '기존 대출 월상환액',
    'equity_amount_krw': '투자 자기자본',
    'borrowed_amount_krw': '투자용 차입금',
    'annual_loan_rate': '투자용 차입금 연이율',
  };
  final Map<String, TextEditingController> _fields = {};
  final _incomeDrop = TextEditingController(text: '0');
  final _expenseRise = TextEditingController(text: '0');
  final _rateRise = TextEditingController(text: '0');
  final _priceChange = TextEditingController(text: '0');
  final _fxChange = TextEditingController(text: '0');
  final _term = TextEditingController(text: '36');
  int _months = 6, _requestId = 0;
  String _repayment = 'interest_only', _currency = 'KRW';
  bool _loading = false, _usingExample = false, _offlineShocks = false;
  String? _error;
  CashFlowResult? _result;
  CashFlowRequest? _analyzedRequest;
  CashFlowSnapshot? _snapshotA, _snapshotB;

  @override
  void initState() {
    super.initState();
    for (final key in _profileLabels.keys) {
      _fields[key] = TextEditingController();
    }
    _currency = widget.initialCurrency;
    _usingExample = widget.isExampleProfile || widget.isOfflineDemo;
    if (widget.initialProfile != null) _fill(widget.initialProfile!);
    if (widget.isOfflineDemo) {
      _fill(OfflineDemoData.profile);
      _loadOffline();
    }
  }

  @override
  void dispose() {
    for (final field in [
      ..._fields.values,
      _incomeDrop,
      _expenseRise,
      _rateRise,
      _priceChange,
      _fxChange,
      _term,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _fill(FinancialProfileInput profile) {
    final data = profile.toJson();
    for (final key in _profileLabels.keys) {
      _fields[key]!.text = key == 'annual_loan_rate'
          ? (profile.annual_loan_rate * 100).toStringAsFixed(2)
          : formatKrwInput('${data[key]}');
    }
  }

  void _invalidate() {
    _requestId++;
    setState(() {
      _result = null;
      _analyzedRequest = null;
      _error = null;
      _loading = false;
    });
  }

  void _loadOffline() {
    _result = CashFlowFixtures.get(_months, _offlineShocks);
    _analyzedRequest = CashFlowRequest(
      financial_profile: OfflineDemoData.profile,
      months: _months,
      investment_currency: 'USD',
      income_change_rate: _offlineShocks ? -.2 : 0,
      expense_change_rate: _offlineShocks ? .1 : 0,
      loan_rate_change: _offlineShocks ? .02 : 0,
      price_change_rate: _offlineShocks ? -.2 : 0,
      exchange_rate_change_rate: _offlineShocks ? -.1 : 0,
    );
  }

  int _moneyField(String key) {
    final value = int.tryParse(_fields[key]!.text.replaceAll(',', '').trim());
    if (value == null || value < 0 || value > 1000000000000000) {
      throw FormatException('${_profileLabels[key]}에 0 이상의 원 단위 금액을 입력해 주세요.');
    }
    return value;
  }

  double _percentage(TextEditingController field, String name) {
    final value = double.tryParse(field.text.trim());
    if (value == null || !value.isFinite) {
      throw FormatException('$name 값을 확인해 주세요.');
    }
    return value / 100;
  }

  CashFlowRequest _readRequest() {
    final equity = _moneyField('equity_amount_krw');
    final borrowed = _moneyField('borrowed_amount_krw');
    final profile = FinancialProfileInput(
      monthly_income_krw: _moneyField('monthly_income_krw'),
      monthly_fixed_expenses_krw: _moneyField('monthly_fixed_expenses_krw'),
      emergency_fund_krw: _moneyField('emergency_fund_krw'),
      existing_loan_balance_krw: _moneyField('existing_loan_balance_krw'),
      monthly_debt_payment_krw: _moneyField('monthly_debt_payment_krw'),
      planned_investment_krw: equity + borrowed,
      equity_amount_krw: equity,
      borrowed_amount_krw: borrowed,
      annual_loan_rate: _percentage(_fields['annual_loan_rate']!, '연이율'),
    );
    final term = int.tryParse(_term.text.trim());
    if (term == null || term < 1 || term > 360) {
      throw const FormatException('투자용 대출 만기는 1~360개월로 입력해 주세요.');
    }
    return CashFlowRequest(
      financial_profile: profile,
      months: _months,
      loan_term_months: term,
      repayment_method: _repayment,
      investment_currency: _currency,
      income_change_rate: -_percentage(_incomeDrop, '소득 감소율'),
      expense_change_rate: _percentage(_expenseRise, '생활비 증가율'),
      loan_rate_change: _percentage(_rateRise, '금리 상승폭'),
      price_change_rate: _percentage(_priceChange, '주가 충격'),
      exchange_rate_change_rate: _currency == 'USD'
          ? _percentage(_fxChange, '환율 충격')
          : 0,
    );
  }

  Future<void> _calculate() async {
    FocusScope.of(context).unfocus();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _analyzedRequest = null;
    });
    try {
      final request = _readRequest();
      final result = await CashFlowApi(widget.apiClient!).analyze(request);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _result = result;
        _analyzedRequest = request;
      });
    } on FormatException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      final labels = {
        ..._profileLabels,
        'months': '기간',
        'loan_term_months': '대출 만기',
        'income_change_rate': '소득 감소율(0~100%)',
        'expense_change_rate': '생활비 증가율(0~100%)',
        'loan_rate_change': '금리 상승폭(적용 연이율 100% 이하)',
        'price_change_rate': '주가 충격(-100~100%)',
        'exchange_rate_change_rate': '환율 충격(-50~50%)',
      };
      setState(
        () => _error = error.statusCode == 404
            ? '현재 연결된 서버에서 이 기능을 사용할 수 없습니다. 완전 가상 사례를 이용해 주세요.'
            : error.fieldErrors.isEmpty
            ? error.message
            : '${error.fieldErrors.map((e) => labels[e.field.split('.').last] ?? '입력 조건').join(', ')}을 확인해 주세요.',
      );
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('월별 현금흐름 · 생활 충격')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '투자 손실과 생활자금을 함께 살펴보세요',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('같은 조건이 유지되는 가정 계산입니다. 투자 평가손익과 실제 현금 지출을 분리합니다.'),
          if (_usingExample)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                widget.isOfflineDemo
                    ? '완전 가상 고정 사례 · 실제 데이터·서버·AI 미사용'
                    : '가상 재무 예시 · 입력을 수정할 수 있습니다.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (!widget.isOfflineDemo) ...[
            TextButton.icon(
              onPressed: () {
                _fill(OfflineDemoData.profile);
                _usingExample = true;
                _invalidate();
              },
              icon: const Icon(Icons.science_outlined),
              label: const Text('가상 재무 예시 채우기'),
            ),
            ExpansionTile(
              title: const Text('재무 조건 입력'),
              initiallyExpanded: widget.initialProfile == null,
              children: [
                const Text(
                  '생활비·고정지출에는 아래 기존 대출 월상환액을 중복해 넣지 마세요. 비상자금은 투자 후 별도로 남겨 둔 현금입니다.',
                ),
                const SizedBox(height: 12),
                for (final entry in _profileLabels.entries)
                  _input(
                    _fields[entry.key]!,
                    entry.value,
                    decimal: entry.key == 'annual_loan_rate',
                    suffix: entry.key == 'annual_loan_rate' ? '%' : '원',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('살펴볼 기간', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final month in [3, 6, 12])
                ChoiceChip(
                  label: Text('$month개월'),
                  selected: _months == month,
                  onSelected: (_) {
                    _invalidate();
                    setState(() {
                      _months = month;
                      if (widget.isOfflineDemo) _loadOffline();
                    });
                  },
                ),
            ],
          ),
          if (widget.isOfflineDemo) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final shocks in [false, true])
                  ChoiceChip(
                    label: Text(
                      shocks ? '소득−20%·생활비+10%·금리+2%p' : '변화 없는 가상 조건',
                    ),
                    selected: _offlineShocks == shocks,
                    onSelected: (_) => setState(() {
                      _offlineShocks = shocks;
                      _loadOffline();
                    }),
                  ),
              ],
            ),
            const Text(
              '투자용 차입금 400만 원 · 연 6% · 36개월 만기 이자 납부. 충격 사례는 달러 자산의 주가 −20%·환율 −10%도 별도로 가정합니다.',
            ),
          ] else ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('투자용 대출 상환 가정'),
              initiallyExpanded: false,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(_repayment),
                  initialValue: _repayment,
                  decoration: const InputDecoration(labelText: '상환 방식'),
                  items: const [
                    DropdownMenuItem(
                      value: 'interest_only',
                      child: Text('이자 납부 · 만기에 원금 전액'),
                    ),
                    DropdownMenuItem(
                      value: 'equal_principal',
                      child: Text('매월 같은 원금 분할상환'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _invalidate();
                      setState(() => _repayment = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _input(_term, '투자용 대출 만기', suffix: '개월', term: true),
                const Text('만기가 분석 기간 안에 오면 원금 상환도 포함합니다. 기존 대출 월상환액은 고정합니다.'),
              ],
            ),
            ExpansionTile(
              title: const Text('생활 충격 설정'),
              subtitle: const Text('소득 감소 · 생활비 증가 · 금리 상승'),
              initiallyExpanded: true,
              children: [
                _input(_incomeDrop, '소득 감소율', suffix: '% 감소', decimal: true),
                _input(
                  _expenseRise,
                  '생활비·고정지출 증가율',
                  suffix: '% 증가',
                  decimal: true,
                ),
                _input(_rateRise, '투자용 대출금리 상승폭', suffix: '%p', decimal: true),
                const Text(
                  '예: 20·10·2 입력 → 소득 −20%, 지출 +10%, 연금리 +2%p. 적용 금리는 투자용 차입금에만 반영됩니다.',
                ),
                TextButton(
                  onPressed: () {
                    _incomeDrop.text = '20';
                    _expenseRise.text = '10';
                    _rateRise.text = '2';
                    _invalidate();
                  },
                  child: const Text('생활 충격 예시 적용'),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('주가·환율 평가 충격'),
              subtitle: const Text('현금 흐름과 별도로 표시'),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final currency in ['KRW', 'USD'])
                      ChoiceChip(
                        label: Text(
                          currency == 'USD' ? '달러 자산 가정' : '원화 자산 가정',
                        ),
                        selected: _currency == currency,
                        onSelected: (_) {
                          _invalidate();
                          setState(() {
                            _currency = currency;
                            if (currency == 'KRW') _fxChange.text = '0';
                          });
                        },
                      ),
                  ],
                ),
                _input(_priceChange, '주가 변화율', decimal: true, suffix: '%'),
                if (_currency == 'USD')
                  _input(_fxChange, '원/달러 환율 변화율', decimal: true, suffix: '%'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _calculate,
              child: Text(_loading ? '현금흐름을 계산하고 있습니다…' : '현금흐름 계산하기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CashFlowScreen(isOfflineDemo: true),
                ),
              ),
              child: const Text('서버 없는 완전 가상 사례 보기'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          if (_result != null &&
              (widget.isOfflineDemo || _analyzedRequest != null)) ...[
            const SizedBox(height: 16),
            const Text('가정 A·B는 이 화면에서만 보관합니다. 화면을 닫으면 사라집니다.'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () => setState(
                    () => _snapshotA = CashFlowSnapshot(
                      _analyzedRequest!,
                      _result!,
                    ),
                  ),
                  child: const Text('가정 A로 보관'),
                ),
                OutlinedButton(
                  onPressed: () => setState(
                    () => _snapshotB = CashFlowSnapshot(
                      _analyzedRequest!,
                      _result!,
                    ),
                  ),
                  child: const Text('가정 B로 보관'),
                ),
              ],
            ),
          ],
          if (_snapshotA != null || _snapshotB != null) ...[
            const SizedBox(height: 12),
            Text(
              '보관 상태 · A ${_snapshotA == null ? '없음' : '${_snapshotA!.request.months}개월'} / B ${_snapshotB == null ? '없음' : '${_snapshotB!.request.months}개월'}',
            ),
            TextButton(
              onPressed: () => setState(() {
                _snapshotA = null;
                _snapshotB = null;
              }),
              child: const Text('보관한 가정 비우기'),
            ),
          ],
          if (_snapshotA != null && _snapshotB != null)
            CashFlowComparisonView(a: _snapshotA!, b: _snapshotB!),
          if (_result != null &&
              (widget.isOfflineDemo || _analyzedRequest != null)) ...[
            const SizedBox(height: 24),
            CashFlowResultView(
              key: ValueKey(_result),
              result: _result!,
              isOfflineDemo: widget.isOfflineDemo,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _input(
    TextEditingController field,
    String label, {
    bool decimal = false,
    String suffix = '원',
    bool term = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: field,
      onChanged: (_) => _invalidate(),
      keyboardType: TextInputType.numberWithOptions(
        decimal: decimal,
        signed: decimal,
      ),
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))]
          : term
          ? [FilteringTextInputFormatter.digitsOnly]
          : const [KrwInputFormatter()],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );
}
