// API DTOs preserve the contract's JSON field names.
// ignore_for_file: non_constant_identifier_names
import 'stress_test_models.dart';

class CashFlowRequest {
  const CashFlowRequest({
    required this.financial_profile,
    this.months = 6,
    this.loan_term_months = 36,
    this.repayment_method = 'interest_only',
    this.income_change_rate = 0,
    this.expense_change_rate = 0,
    this.loan_rate_change = 0,
    this.price_change_rate = 0,
    this.exchange_rate_change_rate = 0,
    this.investment_currency = 'KRW',
  });
  final FinancialProfileInput financial_profile;
  final int months;
  final int loan_term_months;
  final String repayment_method;
  final double income_change_rate;
  final double expense_change_rate;
  final double loan_rate_change;
  final double price_change_rate;
  final double exchange_rate_change_rate;
  final String investment_currency;

  Map<String, dynamic> toJson() => {
    'financial_profile': financial_profile.toJson(),
    'months': months,
    'loan_term_months': loan_term_months,
    'repayment_method': repayment_method,
    'income_change_rate': income_change_rate,
    'expense_change_rate': expense_change_rate,
    'loan_rate_change': loan_rate_change,
    'price_change_rate': price_change_rate,
    'exchange_rate_change_rate': exchange_rate_change_rate,
    'investment_currency': investment_currency,
  };
}

class MonthlyCashFlowResult {
  MonthlyCashFlowResult.fromJson(Map<String, dynamic> json)
    : month = _integer(json, 'month'),
      income_krw = _integer(json, 'income_krw'),
      fixed_expenses_krw = _integer(json, 'fixed_expenses_krw'),
      existing_debt_payment_krw = _integer(json, 'existing_debt_payment_krw'),
      investment_interest_krw = _integer(json, 'investment_interest_krw'),
      investment_principal_payment_krw = _integer(
        json,
        'investment_principal_payment_krw',
      ),
      monthly_net_cash_krw = _integer(json, 'monthly_net_cash_krw'),
      cash_balance_krw = _integer(json, 'cash_balance_krw'),
      cash_shortfall_krw = _integer(json, 'cash_shortfall_krw'),
      investment_loan_balance_krw = _integer(
        json,
        'investment_loan_balance_krw',
      ),
      cumulative_interest_krw = _integer(json, 'cumulative_interest_krw');
  final int month, income_krw, fixed_expenses_krw, existing_debt_payment_krw;
  final int investment_interest_krw, investment_principal_payment_krw;
  final int monthly_net_cash_krw, cash_balance_krw, cash_shortfall_krw;
  final int investment_loan_balance_krw, cumulative_interest_krw;
}

class CashFlowPathResult {
  CashFlowPathResult.fromJson(Map<String, dynamic> json)
    : monthly_points = (json['monthly_points'] as List)
          .map(
            (value) =>
                MonthlyCashFlowResult.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
      total_interest_krw = _integer(json, 'total_interest_krw'),
      total_principal_paid_krw = _integer(json, 'total_principal_paid_krw'),
      ending_cash_balance_krw = _integer(json, 'ending_cash_balance_krw'),
      ending_loan_balance_krw = _integer(json, 'ending_loan_balance_krw'),
      first_shortfall_month = json['first_shortfall_month'] as int?;
  final List<MonthlyCashFlowResult> monthly_points;
  final int total_interest_krw, total_principal_paid_krw;
  final int ending_cash_balance_krw, ending_loan_balance_krw;
  final int? first_shortfall_month;
}

class CashFlowResult {
  CashFlowResult.fromJson(Map<String, dynamic> json)
    : calculation_version = json['calculation_version'] as String,
      months = _integer(json, 'months'),
      initial_cash_krw = _integer(json, 'initial_cash_krw'),
      baseline = CashFlowPathResult.fromJson(
        json['baseline'] as Map<String, dynamic>,
      ),
      shocked = CashFlowPathResult.fromJson(
        json['shocked'] as Map<String, dynamic>,
      ),
      investment_effect = ScenarioResult.fromJson(
        json['investment_effect'] as Map<String, dynamic>,
      ),
      assumptions = (json['assumptions'] as List).cast<String>() {
    if (baseline.monthly_points.length != months ||
        shocked.monthly_points.length != months) {
      throw const FormatException('현금흐름 관측 개월 수가 계약과 다릅니다.');
    }
  }
  final String calculation_version;
  final int months, initial_cash_krw;
  final CashFlowPathResult baseline, shocked;
  final ScenarioResult investment_effect;
  final List<String> assumptions;
}

int _integer(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! int) throw FormatException('$field 필드가 정수가 아닙니다.');
  return value;
}
