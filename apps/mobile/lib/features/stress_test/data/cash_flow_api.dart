import '../../../shared/api/api_client.dart';
import '../models/cash_flow_models.dart';

class CashFlowApi {
  const CashFlowApi(this.client);
  final ApiClient client;
  Future<CashFlowResult> analyze(CashFlowRequest request) async {
    final body = await client.postJson(
      '/api/v1/stress-tests/cash-flow',
      request.toJson(),
    );
    try {
      return CashFlowResult.fromJson(body as Map<String, dynamic>);
    } on TypeError {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '현금흐름 응답 형식이 올바르지 않습니다.',
      );
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '현금흐름 응답 필드를 확인할 수 없습니다.',
      );
    }
  }
}
