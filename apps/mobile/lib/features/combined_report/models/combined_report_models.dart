// API DTO 프로퍼티는 docs/API_CONTRACT.md의 snake_case 필드명을 그대로 쓴다.
// ignore_for_file: non_constant_identifier_names

import '../../financial_health/models/financial_health_models.dart';
import '../../market_risk/models/market_risk_models.dart';
import '../../stress_test/models/stress_test_models.dart';

class CombinedAnalysisRequest {
  const CombinedAnalysisRequest({
    required this.financial_profile,
    required this.instrument,
    required this.period_start,
    required this.period_end,
  });

  final FinancialProfileInput financial_profile;
  final Instrument instrument;
  final String period_start;
  final String period_end;

  Map<String, dynamic> toJson() {
    return {
      'financial_profile': financial_profile.toJson(),
      'instrument': instrument.toJson(),
      'period_start': period_start,
      'period_end': period_end,
    };
  }
}

class CombinedAnalysisResult {
  const CombinedAnalysisResult({
    required this.request_id,
    required this.calculated_at,
    required this.calculation_version,
    required this.financial_health,
    required this.market_risk,
    required this.mdd_impact,
    required this.scenarios,
    required this.warnings,
    required this.disclaimer,
  });

  final String request_id;
  final String calculated_at;
  final String calculation_version;
  final FinancialHealthResult financial_health;
  final MarketRiskResult? market_risk;
  final ScenarioResult? mdd_impact;
  final List<ScenarioResult> scenarios;
  final List<String> warnings;
  final String disclaimer;

  factory CombinedAnalysisResult.fromJson(Map<String, dynamic> json) {
    final financialHealth = _readMap(json, 'financial_health');
    final marketRisk = _readNullableMap(json, 'market_risk');
    final mddImpact = _readNullableMap(json, 'mdd_impact');
    final rawScenarios = json['scenarios'];
    if (rawScenarios is! List) {
      throw const FormatException('scenarios 필드가 array가 아닙니다.');
    }

    return CombinedAnalysisResult(
      request_id: _readString(json, 'request_id'),
      calculated_at: _readString(json, 'calculated_at'),
      calculation_version: _readString(json, 'calculation_version'),
      financial_health: FinancialHealthResult.fromJson(financialHealth),
      market_risk: marketRisk == null
          ? null
          : MarketRiskResult.fromJson(marketRisk),
      mdd_impact: mddImpact == null ? null : ScenarioResult.fromJson(mddImpact),
      scenarios: rawScenarios
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('scenarios 항목이 object가 아닙니다.');
            }
            return ScenarioResult.fromJson(item);
          })
          .toList(growable: false),
      warnings: _readStringList(json, 'warnings'),
      disclaimer: _readString(json, 'disclaimer'),
    );
  }
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$key 필드가 object가 아닙니다.');
}

Map<String, dynamic>? _readNullableMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$key 필드가 object | null이 아닙니다.');
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('$key 필드가 string이 아닙니다.');
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>().toList(growable: false);
  }
  throw FormatException('$key 필드가 string[]이 아닙니다.');
}
