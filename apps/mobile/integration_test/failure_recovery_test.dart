import 'dart:async';
import 'dart:convert';

import 'package:financial_shock_preview/features/combined_report/presentation/combined_report_screen.dart';
import 'package:financial_shock_preview/features/combined_report/presentation/widgets/impact_summary_card.dart';
import 'package:financial_shock_preview/features/market_risk/models/market_risk_models.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/market_risk_screen.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/widgets/market_risk_card.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

import 'support/qa_fixtures.dart';

const _instrument = Instrument(
  symbol: 'AAPL',
  market: 'NASDAQ',
  name: 'QA 가상 종목',
  currency: 'USD',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final status in [429, 500]) {
    testWidgets('종목 요청 $status 오류 후 재시도 복구', (tester) async {
      var calls = 0;
      final client = ApiClient(
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? _error(status, '주가 데이터를 불러오지 못했습니다.')
              : _json(qaCombinedResponse()['market_risk']!);
        }),
      );
      addTearDown(client.close);
      await _show(
        tester,
        MarketRiskScreen(apiClient: client, initialInstrument: _instrument),
      );
      await _scrollTo(tester, find.text('주가 데이터를 불러오지 못했습니다.'));
      expect(find.text('주가 데이터를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.byType(MarketRiskCard), findsNothing);
      await tester.tap(find.text('재시도'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byType(MarketRiskCard));
      expect(find.byType(MarketRiskCard), findsOneWidget);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('느린 응답 시간 초과 후 재시도와 늦은 응답 무시', (tester) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final client = ApiClient(
      timeout: const Duration(milliseconds: 350),
      client: MockClient((_) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(_json(qaCombinedResponse()['market_risk']!));
      }),
    );
    addTearDown(client.close);
    await _show(
      tester,
      MarketRiskScreen(apiClient: client, initialInstrument: _instrument),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _scrollTo(tester, find.text('서버 응답 시간이 초과되었습니다.'));
    expect(find.text('서버 응답 시간이 초과되었습니다.'), findsOneWidget);
    expect(find.byType(MarketRiskCard), findsNothing);
    await tester.tap(find.text('재시도'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byType(MarketRiskCard));
    expect(find.byType(MarketRiskCard), findsOneWidget);
    pending.complete(_error(500, '이전 요청 오류'));
    await tester.pumpAndSettle();
    expect(find.text('이전 요청 오류'), findsNothing);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 제공자 장애의 기본 설명과 계산 결과 유지', (tester) async {
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/explanations') {
          return _json({
            'source': 'template',
            'fallback_reason': 'provider_unavailable',
            'summary': 'QA 가상 손실은 3,000,000원입니다.',
            'caution': 'QA 가상 데이터이며 미래 결과를 예측하지 않습니다.',
          });
        }
        return _json(qaCombinedResponse());
      }),
    );
    addTearDown(client.close);
    await _show(tester, _report(client));
    expect(find.byType(ImpactSummaryCard), findsOneWidget);
    await _scrollTo(tester, find.text('QA 가상 손실은 3,000,000원입니다.'));
    expect(find.text('검증된 기본 설명'), findsOneWidget);
    expect(find.textContaining('AI 서비스 응답을 받지 못해'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('설명 API 실패 후 설명만 재요청하고 계산은 유지', (tester) async {
    var reportCalls = 0;
    var explanationCalls = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/explanations') {
          explanationCalls++;
          if (explanationCalls == 1) return _error(503, '설명 연결 실패');
          return _json({
            'source': 'llm',
            'fallback_reason': null,
            'summary': '복구된 QA 가상 설명입니다.',
            'caution': 'QA 가상 데이터입니다.',
          });
        }
        reportCalls++;
        return _json(qaCombinedResponse());
      }),
    );
    addTearDown(client.close);
    await _show(tester, _report(client));
    expect(find.byType(ImpactSummaryCard), findsOneWidget);
    await _scrollTo(tester, find.text('설명 다시 요청'));
    await tester.tap(find.text('설명 다시 요청'));
    await tester.pumpAndSettle();
    expect(find.text('AI 쉬운 설명'), findsOneWidget);
    expect(find.text('복구된 QA 가상 설명입니다.'), findsOneWidget);
    expect(reportCalls, 1);
    expect(explanationCalls, 2);
    expect(tester.takeException(), isNull);
  });
}

CombinedReportScreen _report(ApiClient client) => CombinedReportScreen(
  apiClient: client,
  financialProfile: qaProfile,
  instrument: _instrument,
  periodStart: '2026-07-01',
  periodEnd: '2026-09-29',
);

Future<void> _show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int status, String message) => _json({
  'error': {
    'code': 'MARKET_DATA_UNAVAILABLE',
    'message': message,
    'field_errors': <Object>[],
    'request_id': 'synthetic-qa',
  },
}, status: status);
