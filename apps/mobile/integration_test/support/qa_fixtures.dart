import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';

const qaProfile = FinancialProfileInput(
  monthly_income_krw: 3000000,
  monthly_fixed_expenses_krw: 1500000,
  emergency_fund_krw: 5000000,
  existing_loan_balance_krw: 10000000,
  monthly_debt_payment_krw: 400000,
  planned_investment_krw: 10000000,
  equity_amount_krw: 6000000,
  borrowed_amount_krw: 4000000,
  annual_loan_rate: 0.06,
);

Map<String, dynamic> qaCombinedResponse() {
  final mdd = {
    'scenario_key': ScenarioKeys.historicalMdd,
    'label': '과거 MDD',
    'assumed_return_rate': -0.3,
    'projected_investment_value_krw': 7000000,
    'investment_pnl_krw': -3000000,
    'investment_loss_krw': 3000000,
    'reported_total_debt_krw': 14000000,
    'net_investment_equity_krw': 3000000,
    'loss_to_equity_ratio': 0.5,
    'loss_to_emergency_fund_ratio': 0.6,
    'loss_to_monthly_fixed_expenses': 2.0,
    'estimated_annual_interest_krw': 240000,
    'estimated_monthly_interest_krw': 20000,
    'recovery_required_rate': 3 / 7,
    'unavailable_reasons': <String>[],
  };
  return {
    'request_id': 'device-test',
    'calculated_at': '2026-10-28T12:00:00Z',
    'calculation_version': '1.0.0',
    'financial_health': {
      'monthly_surplus_krw': 1100000,
      'emergency_runway_months': 2.631579,
      'leverage_ratio': 0.4,
      'estimated_monthly_interest_krw': 20000,
      'reported_total_debt_krw': 14000000,
      'unavailable_reasons': <String>[],
    },
    'market_risk': {
      'instrument': {
        'symbol': 'AAPL',
        'market': 'NASDAQ',
        'name': 'QA 가상 종목',
        'currency': 'USD',
      },
      'period_start': '2026-07-01',
      'period_end': '2026-09-29',
      'data_as_of': '2026-09-29',
      'fx_rate_as_of': '2026-09-29',
      'data_source': 'synthetic_qa',
      'observation_count': 63,
      'period_return_rate': -0.02,
      'annualized_volatility': 0.29,
      'max_drawdown_rate': -0.3,
      'peak_date': '2026-07-28',
      'trough_date': '2026-09-09',
      'recovery_date': null,
      'warnings': <String>[],
    },
    'mdd_impact': mdd,
    'scenarios': [mdd],
    'warnings': <String>[],
    'disclaimer': '교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다.',
  };
}
