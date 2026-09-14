import '../../../shared/api/api_client.dart';
import '../../stress_test/models/stress_test_models.dart';
import '../models/financial_health_models.dart';

class FinancialHealthApi {
  const FinancialHealthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<FinancialHealthResult> analyze(FinancialProfileInput profile) async {
    // 동일한 FinancialProfileInput 계약을 Stress Test와 재사용한다.
    // 같은 재무정보 DTO를 Slice마다 새로 만들지 않는 것이 AGENTS.md 규칙과 맞다.
    final decoded = await _apiClient.postJson(
      '/api/v1/financial-health/analyze',
      profile.toJson(),
    );

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '금융체력 분석 응답 형식이 올바르지 않습니다.',
      );
    }

    try {
      return FinancialHealthResult.fromJson(decoded);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '금융체력 분석 응답 필드가 API 계약과 다릅니다.',
      );
    } on TypeError {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '금융체력 분석 응답 필드가 API 계약과 다릅니다.',
      );
    }
  }
}
