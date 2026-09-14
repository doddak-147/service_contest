// API DTO 프로퍼티는 docs/API_CONTRACT.md의 snake_case 필드명을 그대로 쓴다.
// ignore_for_file: non_constant_identifier_names

class FinancialHealthResult {
  const FinancialHealthResult({
    required this.monthly_surplus_krw,
    required this.emergency_runway_months,
    required this.leverage_ratio,
    required this.estimated_monthly_interest_krw,
    required this.reported_total_debt_krw,
    required this.unavailable_reasons,
  });

  final int monthly_surplus_krw;
  final double? emergency_runway_months;
  final double? leverage_ratio;
  final int estimated_monthly_interest_krw;
  final int reported_total_debt_krw;
  final List<String> unavailable_reasons;

  factory FinancialHealthResult.fromJson(Map<String, dynamic> json) {
    // Flutter는 서버가 계산한 숫자를 검증해서 읽기만 한다.
    // 계산식을 모바일에 복제하지 않아 서버와 앱의 결과가 어긋나는 것을 막는다.
    return FinancialHealthResult(
      monthly_surplus_krw: _readInt(json, 'monthly_surplus_krw'),
      emergency_runway_months: _readNullableDouble(
        json,
        'emergency_runway_months',
      ),
      leverage_ratio: _readNullableDouble(json, 'leverage_ratio'),
      estimated_monthly_interest_krw: _readInt(
        json,
        'estimated_monthly_interest_krw',
      ),
      reported_total_debt_krw: _readInt(json, 'reported_total_debt_krw'),
      unavailable_reasons: _readStringList(json, 'unavailable_reasons'),
    );
  }
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 필드가 integer가 아닙니다.');
  }
  return value;
}

double? _readNullableDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! num) {
    throw FormatException('$key 필드가 number가 아닙니다.');
  }
  return value.toDouble();
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key 필드가 string[]이 아닙니다.');
  }
  return value.cast<String>().toList(growable: false);
}
