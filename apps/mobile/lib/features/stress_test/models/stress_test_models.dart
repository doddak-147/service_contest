// API DTO 프로퍼티는 docs/API_CONTRACT.md의 snake_case 필드명을 그대로 쓴다.
// ignore_for_file: non_constant_identifier_names

abstract final class ScenarioKeys {
  static const up20 = 'up_20';
  static const flat = 'flat';
  static const down10 = 'down_10';
  static const down20 = 'down_20';
  static const down30 = 'down_30';
  static const down40 = 'down_40';
  static const down50 = 'down_50';
  static const historicalMdd = 'historical_mdd';

  static const all = {
    up20,
    flat,
    down10,
    down20,
    down30,
    down40,
    down50,
    historicalMdd,
  };

  static const declines = [down10, down20, down30, down40, down50];
}

class FinancialProfileInput {
  const FinancialProfileInput({
    required this.monthly_income_krw,
    required this.monthly_fixed_expenses_krw,
    required this.emergency_fund_krw,
    required this.existing_loan_balance_krw,
    required this.monthly_debt_payment_krw,
    required this.planned_investment_krw,
    required this.equity_amount_krw,
    required this.borrowed_amount_krw,
    required this.annual_loan_rate,
  });

  final int monthly_income_krw;
  final int monthly_fixed_expenses_krw;
  final int emergency_fund_krw;
  final int existing_loan_balance_krw;
  final int monthly_debt_payment_krw;
  final int planned_investment_krw;
  final int equity_amount_krw;
  final int borrowed_amount_krw;
  final double annual_loan_rate;

  Map<String, dynamic> toJson() {
    return {
      'monthly_income_krw': monthly_income_krw,
      'monthly_fixed_expenses_krw': monthly_fixed_expenses_krw,
      'emergency_fund_krw': emergency_fund_krw,
      'existing_loan_balance_krw': existing_loan_balance_krw,
      'monthly_debt_payment_krw': monthly_debt_payment_krw,
      'planned_investment_krw': planned_investment_krw,
      'equity_amount_krw': equity_amount_krw,
      'borrowed_amount_krw': borrowed_amount_krw,
      'annual_loan_rate': annual_loan_rate,
    };
  }
}

class StressTestRequest {
  const StressTestRequest({
    required this.financial_profile,
    required this.historical_mdd_rate,
  });

  final FinancialProfileInput financial_profile;
  final double? historical_mdd_rate;

  Map<String, dynamic> toJson() {
    return {
      'financial_profile': financial_profile.toJson(),
      'historical_mdd_rate': historical_mdd_rate,
    };
  }
}

class ScenarioResult {
  const ScenarioResult({
    required this.scenario_key,
    required this.label,
    required this.assumed_return_rate,
    required this.projected_investment_value_krw,
    required this.investment_pnl_krw,
    required this.investment_loss_krw,
    required this.reported_total_debt_krw,
    required this.net_investment_equity_krw,
    required this.loss_to_equity_ratio,
    required this.loss_to_emergency_fund_ratio,
    required this.loss_to_monthly_fixed_expenses,
    required this.estimated_annual_interest_krw,
    required this.estimated_monthly_interest_krw,
    required this.recovery_required_rate,
    required this.unavailable_reasons,
  });

  final String scenario_key;
  final String label;
  final double assumed_return_rate;
  final int projected_investment_value_krw;
  final int investment_pnl_krw;
  final int investment_loss_krw;
  final int reported_total_debt_krw;
  final int net_investment_equity_krw;
  final double? loss_to_equity_ratio;
  final double? loss_to_emergency_fund_ratio;
  final double? loss_to_monthly_fixed_expenses;
  final int estimated_annual_interest_krw;
  final int estimated_monthly_interest_krw;
  final double? recovery_required_rate;
  final List<String> unavailable_reasons;

  factory ScenarioResult.fromJson(Map<String, dynamic> json) {
    final scenarioKey = _readString(json, 'scenario_key');
    if (!ScenarioKeys.all.contains(scenarioKey)) {
      throw const FormatException('지원하지 않는 scenario_key입니다.');
    }

    return ScenarioResult(
      scenario_key: scenarioKey,
      label: _readString(json, 'label'),
      assumed_return_rate: _readDouble(json, 'assumed_return_rate'),
      projected_investment_value_krw: _readInt(
        json,
        'projected_investment_value_krw',
      ),
      investment_pnl_krw: _readInt(json, 'investment_pnl_krw'),
      investment_loss_krw: _readInt(json, 'investment_loss_krw'),
      reported_total_debt_krw: _readInt(json, 'reported_total_debt_krw'),
      net_investment_equity_krw: _readInt(json, 'net_investment_equity_krw'),
      loss_to_equity_ratio: _readNullableDouble(json, 'loss_to_equity_ratio'),
      loss_to_emergency_fund_ratio: _readNullableDouble(
        json,
        'loss_to_emergency_fund_ratio',
      ),
      loss_to_monthly_fixed_expenses: _readNullableDouble(
        json,
        'loss_to_monthly_fixed_expenses',
      ),
      estimated_annual_interest_krw: _readInt(
        json,
        'estimated_annual_interest_krw',
      ),
      estimated_monthly_interest_krw: _readInt(
        json,
        'estimated_monthly_interest_krw',
      ),
      recovery_required_rate: _readNullableDouble(
        json,
        'recovery_required_rate',
      ),
      unavailable_reasons: _readStringList(json, 'unavailable_reasons'),
    );
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('$key 필드가 string이 아닙니다.');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key 필드가 integer가 아닙니다.');
}

double _readDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$key 필드가 number가 아닙니다.');
}

double? _readNullableDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$key 필드가 number | null이 아닙니다.');
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  throw FormatException('$key 필드가 string[]이 아닙니다.');
}
