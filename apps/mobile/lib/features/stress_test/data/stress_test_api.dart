import '../../../shared/api/api_client.dart';
import '../models/stress_test_models.dart';

class StressTestApi {
  const StressTestApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ScenarioResult>> analyze(StressTestRequest request) async {
    final decoded = await _apiClient.postJson(
      '/api/v1/stress-tests/analyze',
      request.toJson(),
    );
    if (decoded is! List) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Stress Test 응답 형식이 올바르지 않습니다.',
      );
    }

    try {
      return decoded
          .map((item) => ScenarioResult.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Stress Test 응답 필드가 API 계약과 다릅니다.',
      );
    } on TypeError {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Stress Test 응답 필드가 API 계약과 다릅니다.',
      );
    }
  }
}
