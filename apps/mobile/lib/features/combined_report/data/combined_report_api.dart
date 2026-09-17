import '../../../shared/api/api_client.dart';
import '../models/combined_report_models.dart';

class CombinedReportApi {
  const CombinedReportApi(this._apiClient);

  final ApiClient _apiClient;

  Future<CombinedAnalysisResult> analyze(
    CombinedAnalysisRequest request,
  ) async {
    final decoded = await _apiClient.postJson(
      '/api/v1/combined-analyses',
      request.toJson(),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결합 Report 응답 형식이 올바르지 않습니다.',
      );
    }

    try {
      return CombinedAnalysisResult.fromJson(decoded);
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결합 Report 응답 필드가 API 계약과 다릅니다.',
      );
    } on TypeError {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '결합 Report 응답 필드가 API 계약과 다릅니다.',
      );
    }
  }
}
