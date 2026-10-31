import 'dart:async';
import 'dart:convert';

import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('서버의 30초 대기 뒤 기본 설명 응답을 받는다', (tester) async {
    final pending = Completer<http.Response>();
    final apiClient = ApiClient(client: MockClient((_) => pending.future));
    addTearDown(apiClient.close);
    final response = apiClient.getJson('/health');
    await tester.pump(const Duration(seconds: 31));
    pending.complete(http.Response('{"status":"ok"}', 200));
    await tester.pump();
    expect(await response, {'status': 'ok'});
  });

  testWidgets('지속되는 응답 지연은 시간 초과 처리하고 다음 요청은 복구한다', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final apiClient = ApiClient(
      client: MockClient((_) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(http.Response('{"status":"ok"}', 200));
      }),
    );
    addTearDown(apiClient.close);
    final failed = expectLater(
      apiClient.getJson('/health'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'REQUEST_TIMEOUT'),
      ),
    );
    await tester.pump(const Duration(seconds: 41));
    await failed;
    expect(await apiClient.getJson('/health'), {'status': 'ok'});
    pending.complete(http.Response('{"status":"old"}', 200));
    await tester.pump();
  });

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

  test('getList returns parsed json array', () async {
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/instruments/search');
        return http.Response.bytes(
          utf8.encode(
            '[{"symbol":"005930","market":"KRX","name":"삼성전자","currency":"KRW"}]',
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    final list = await apiClient.getList('/api/v1/instruments/search?q=삼성');
    expect(list.length, 1);
    expect((list[0] as Map)['symbol'], '005930');
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
