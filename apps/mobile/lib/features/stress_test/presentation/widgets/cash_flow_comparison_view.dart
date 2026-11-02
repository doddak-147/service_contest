import 'package:flutter/material.dart';
import '../../models/cash_flow_models.dart';
import 'cash_flow_result_view.dart';

class CashFlowSnapshot {
  const CashFlowSnapshot(this.request, this.result);
  final CashFlowRequest request;
  final CashFlowResult result;
}

class CashFlowComparisonView extends StatelessWidget {
  const CashFlowComparisonView({required this.a, required this.b, super.key});
  final CashFlowSnapshot a, b;
  static const _labels = {
    'monthly_income_krw': '월 소득',
    'monthly_fixed_expenses_krw': '생활비·고정지출',
    'emergency_fund_krw': '시작 비상자금',
    'existing_loan_balance_krw': '기존 대출 잔액',
    'monthly_debt_payment_krw': '기존 월상환액',
    'planned_investment_krw': '총 투자 예정금액',
    'equity_amount_krw': '투자 자기자본',
    'borrowed_amount_krw': '투자용 차입금',
    'annual_loan_rate': '투자용 연금리',
    'months': '분석 기간',
    'loan_term_months': '투자용 대출 만기',
    'repayment_method': '원금 상환 방식',
    'income_change_rate': '소득 변화',
    'expense_change_rate': '생활비 변화',
    'loan_rate_change': '금리 상승폭',
    'price_change_rate': '주가 변화',
    'exchange_rate_change_rate': '환율 변화',
    'investment_currency': '자산 통화',
  };
  Map<String, dynamic> _conditions(CashFlowRequest r) {
    final rest = r.toJson()..remove('financial_profile');
    return {...r.financial_profile.toJson(), ...rest};
  }

  String _format(String key, dynamic value) {
    if (key.endsWith('_krw')) return cashMoney(value as int);
    if (key == 'months' || key == 'loan_term_months') return '$value개월';
    if (key == 'repayment_method') {
      return value == 'interest_only' ? '이자 납부·만기 원금' : '원금 균등분할';
    }
    if (value is num) {
      final text = (value * 100)
          .toStringAsFixed(6)
          .replaceFirst(RegExp(r'\.?0+$'), '');
      return '$text${key == 'loan_rate_change' ? '%p' : '%'}';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final ca = _conditions(a.request), cb = _conditions(b.request);
    final changed = _labels.keys.where((key) => ca[key] != cb[key]).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('가정 A · B 비교', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('현재 화면에서 보관한 계산 결과입니다. 어느 조건이 적합한지 판정하지 않습니다.'),
            if (a.request.months != b.request.months)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '분석 기간이 다릅니다. 누적 금액 차이에는 기간의 영향도 포함됩니다.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
            _resultRow(
              '마지막 현금 여력',
              a.result.shocked.ending_cash_balance_krw,
              b.result.shocked.ending_cash_balance_krw,
            ),
            _resultRow(
              '누적 투자용 이자',
              a.result.shocked.total_interest_krw,
              b.result.shocked.total_interest_krw,
            ),
            _resultRow(
              '첫 달 지출·상환 후 남는 돈',
              a.result.shocked.monthly_points.first.monthly_net_cash_krw,
              b.result.shocked.monthly_points.first.monthly_net_cash_krw,
            ),
            _resultRow(
              '남은 투자용 대출 원금',
              a.result.shocked.ending_loan_balance_krw,
              b.result.shocked.ending_loan_balance_krw,
            ),
            _resultRow(
              '즉시 충격 가정 투자자산',
              a.result.investment_effect.projected_investment_value_krw,
              b.result.investment_effect.projected_investment_value_krw,
            ),
            ExpansionTile(
              title: Text('달라진 조건 ${changed.length}개'),
              initiallyExpanded: true,
              children: [
                if (changed.isEmpty) const Text('두 가정의 입력 조건이 같습니다.'),
                for (final key in changed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _labels[key]!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'A ${_format(key, ca[key])} → B ${_format(key, cb[key])}',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, int va, int vb) {
    final delta = vb - va;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [Text('A ${cashMoney(va)}'), Text('B ${cashMoney(vb)}')],
          ),
          Text('B − A: ${delta > 0 ? '+' : ''}${cashMoney(delta)}'),
        ],
      ),
    );
  }
}
