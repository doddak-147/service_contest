import 'package:financial_shock_preview/features/financial_health/models/financial_health_models.dart';
import 'package:financial_shock_preview/features/combined_report/models/combined_report_models.dart';
import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ExplanationInput은 원본 재무정보 없이 계약 필드만 직렬화한다', () {
    const input = ExplanationInput(
      scenario_key: ScenarioKeys.historicalMdd,
      assumed_return_rate: -0.3,
      investment_loss_krw: 3000000,
      loss_to_equity_ratio: 0.5,
      loss_to_emergency_fund_ratio: 0.6,
      loss_to_monthly_fixed_expenses: 2,
      net_investment_equity_krw: 3000000,
      estimated_monthly_interest_krw: 20000,
      market_max_drawdown_rate: -0.3,
      warnings: [],
    );

    expect(input.toJson().keys, {
      'scenario_key',
      'assumed_return_rate',
      'investment_loss_krw',
      'loss_to_equity_ratio',
      'loss_to_emergency_fund_ratio',
      'loss_to_monthly_fixed_expenses',
      'net_investment_equity_krw',
      'estimated_monthly_interest_krw',
      'market_max_drawdown_rate',
      'warnings',
    });
  });

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

  test('FinancialHealthResult는 계약 응답을 파싱한다', () {
    final result = FinancialHealthResult.fromJson({
      'monthly_surplus_krw': 1100000,
      'emergency_runway_months': 2.631579,
      'leverage_ratio': 0.4,
      'estimated_monthly_interest_krw': 20000,
      'reported_total_debt_krw': 14000000,
      'unavailable_reasons': <String>[],
    });

    expect(result.monthly_surplus_krw, 1100000);
    expect(result.emergency_runway_months, 2.631579);
    expect(result.leverage_ratio, 0.4);
    expect(result.estimated_monthly_interest_krw, 20000);
  });

  test('FinancialHealthResult는 계산 불가 null과 사유 코드를 보존한다', () {
    final result = FinancialHealthResult.fromJson({
      'monthly_surplus_krw': 3000000,
      'emergency_runway_months': null,
      'leverage_ratio': 0.4,
      'estimated_monthly_interest_krw': 20000,
      'reported_total_debt_krw': 14000000,
      'unavailable_reasons': ['ZERO_ESSENTIAL_OUTFLOW'],
    });

    expect(result.emergency_runway_months, isNull);
    expect(result.unavailable_reasons, ['ZERO_ESSENTIAL_OUTFLOW']);
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
