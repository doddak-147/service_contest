import '../../../shared/api/api_client.dart';
import '../models/combined_report_models.dart';

class ExplanationApi {
  const ExplanationApi(this._apiClient);

  final ApiClient _apiClient;

  Future<ExplanationResult> explain(ExplanationInput request) async {
    final decoded = await _apiClient.postJson(
      '/api/v1/explanations',
      request.toJson(),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결과 설명 응답 형식이 올바르지 않습니다.',
      );
    }

    try {
      return ExplanationResult.fromJson(decoded);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결과 설명 응답 필드가 API 계약과 다릅니다.',
      );
    } on TypeError {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결과 설명 응답 필드가 API 계약과 다릅니다.',
      );
    }
  }
}
