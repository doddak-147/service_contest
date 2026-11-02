import '../../../shared/api/api_client.dart';
import '../models/risk_lessons.dart';

class RiskQuizApi {
  const RiskQuizApi(this.client);
  final ApiClient client;
  Future<RiskQuizRound> generate(int seed) async {
    final body = await client.postJson('/api/v1/risk-learning/quizzes', {
      'seed': seed,
    });
    try {
      return RiskQuizRound.fromJson(body as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '문제 구성을 확인할 수 없습니다.',
      );
    }
  }
}
