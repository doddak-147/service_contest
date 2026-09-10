import 'dart:convert';

import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('GET /health 응답을 읽는다', () async {
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response.bytes(
          utf8.encode('{"status":"ok"}'),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    final response = await apiClient.getJson('/health');

    expect(response, {'status': 'ok'});
  });

  test('공통 오류 응답의 field_errors를 보존한다', () async {
    final apiClient = ApiClient(
      client: MockClient((_) async {
        final payload = jsonEncode({
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': '입력값을 확인해 주세요.',
            'field_errors': [
              {
                'field': 'equity_amount_krw',
                'reason': 'INVESTMENT_SUM_MISMATCH',
              },
            ],
            'request_id': 'request-1',
          },
        });
        return http.Response.bytes(
          utf8.encode(payload),
          422,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    await expectLater(
      apiClient.postJson('/api/v1/stress-tests/analyze', const {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'VALIDATION_ERROR')
            .having(
              (error) => error.fieldErrors.single.field,
              'field',
              'equity_amount_krw',
            )
            .having(
              (error) => error.fieldErrors.single.reason,
              'reason',
              'INVESTMENT_SUM_MISMATCH',
            ),
      ),
    );
  });
}
