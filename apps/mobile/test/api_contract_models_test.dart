import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FinancialProfileInput은 API 계약 필드명을 그대로 직렬화한다', () {
    const profile = FinancialProfileInput(
      monthly_income_krw: 3000000,
      monthly_fixed_expenses_krw: 1800000,
      emergency_fund_krw: 0,
      existing_loan_balance_krw: 0,
      monthly_debt_payment_krw: 0,
      planned_investment_krw: 15000000,
      equity_amount_krw: 5000000,
      borrowed_amount_krw: 10000000,
      annual_loan_rate: 0.06,
    );

    expect(profile.toJson(), {
      'monthly_income_krw': 3000000,
      'monthly_fixed_expenses_krw': 1800000,
      'emergency_fund_krw': 0,
      'existing_loan_balance_krw': 0,
      'monthly_debt_payment_krw': 0,
      'planned_investment_krw': 15000000,
      'equity_amount_krw': 5000000,
      'borrowed_amount_krw': 10000000,
      'annual_loan_rate': 0.06,
    });
  });

  test('ScenarioResult는 계약 응답을 파싱한다', () {
    final result = ScenarioResult.fromJson({
      'scenario_key': 'down_20',
      'label': '20% 하락',
      'assumed_return_rate': -0.2,
      'projected_investment_value_krw': 12000000,
      'investment_pnl_krw': -3000000,
      'investment_loss_krw': 3000000,
      'reported_total_debt_krw': 10000000,
      'net_investment_equity_krw': 2000000,
      'loss_to_equity_ratio': 0.6,
      'loss_to_emergency_fund_ratio': null,
      'loss_to_monthly_fixed_expenses': 1.666667,
      'estimated_annual_interest_krw': 600000,
      'estimated_monthly_interest_krw': 50000,
      'recovery_required_rate': 0.25,
      'unavailable_reasons': ['ZERO_EMERGENCY_FUND'],
    });

    expect(result.scenario_key, ScenarioKeys.down20);
    expect(result.investment_loss_krw, 3000000);
    expect(result.estimated_annual_interest_krw, 600000);
    expect(result.loss_to_monthly_fixed_expenses, 1.666667);
  });

  test('정의되지 않은 scenario_key는 거부한다', () {
    expect(
      () => ScenarioResult.fromJson({
        'scenario_key': 'down_60',
        'label': '60% 하락',
      }),
      throwsFormatException,
    );
  });
}
