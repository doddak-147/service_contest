// API DTO 프로퍼티는 docs/API_CONTRACT.md의 snake_case 필드명을 그대로 쓴다.
// ignore_for_file: non_constant_identifier_names

class Instrument {
  const Instrument({
    required this.symbol,
    required this.market,
    required this.name,
    required this.currency,
  });

  final String symbol;
  final String market;
  final String name;
  final String currency;

  factory Instrument.fromJson(Map<String, dynamic> json) {
    return Instrument(
      symbol: _readString(json, 'symbol'),
      market: _readString(json, 'market'),
      name: _readString(json, 'name'),
      currency: _readString(json, 'currency'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'market': market,
      'name': name,
      'currency': currency,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Instrument &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol &&
          market == other.market;

  @override
  int get hashCode => symbol.hashCode ^ market.hashCode;
}

class MarketRiskResult {
  const MarketRiskResult({
    required this.instrument,
    required this.period_start,
    required this.period_end,
    required this.data_as_of,
    required this.data_source,
    required this.observation_count,
    required this.period_return_rate,
    required this.annualized_volatility,
    required this.max_drawdown_rate,
    required this.peak_date,
    required this.trough_date,
    required this.recovery_date,
    required this.warnings,
  });

  final Instrument instrument;
  final String period_start;
  final String period_end;
  final String data_as_of;
  final String data_source;
  final int observation_count;
  final double? period_return_rate;
  final double? annualized_volatility;
  final double? max_drawdown_rate;
  final String? peak_date;
  final String? trough_date;
  final String? recovery_date;
  final List<String> warnings;

  factory MarketRiskResult.fromJson(Map<String, dynamic> json) {
    final rawInstrument = json['instrument'];
    if (rawInstrument is! Map<String, dynamic>) {
      throw const FormatException('instrument 필드가 object가 아닙니다.');
    }

    return MarketRiskResult(
      instrument: Instrument.fromJson(rawInstrument),
      period_start: _readString(json, 'period_start'),
      period_end: _readString(json, 'period_end'),
      data_as_of: _readString(json, 'data_as_of'),
      data_source: _readString(json, 'data_source'),
      observation_count: _readInt(json, 'observation_count'),
      period_return_rate: _readNullableDouble(json, 'period_return_rate'),
      annualized_volatility: _readNullableDouble(json, 'annualized_volatility'),
      max_drawdown_rate: _readNullableDouble(json, 'max_drawdown_rate'),
      peak_date: _readNullableString(json, 'peak_date'),
      trough_date: _readNullableString(json, 'trough_date'),
      recovery_date: _readNullableString(json, 'recovery_date'),
      warnings: _readStringList(json, 'warnings'),
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

String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$key 필드가 string | null이 아닙니다.');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key 필드가 integer가 아닙니다.');
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
