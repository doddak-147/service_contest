import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/widgets/market_history_view.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:financial_shock_preview/shared/widgets/comparison_line_chart.dart';

void main() {
  test('가상 곡선과 가상 요약의 기준점·MDD가 일치한다', () {
    final history = OfflineDemoData.priceHistory;
    expect(history.points.length, history.market_risk.observation_count);
    expect(history.points.first.krw_price_index, 100);
    expect(history.points.first.usd_price_index, 100);
    final peak = history.points.firstWhere(
      (p) => p.date == history.market_risk.peak_date,
    );
    final trough = history.points.firstWhere(
      (p) => p.date == history.market_risk.trough_date,
    );
    expect(
      trough.krw_price_index / peak.krw_price_index - 1,
      closeTo(-.3, .000001),
    );
    expect(history.points.last.krw_price_index, 95);
  });

  testWidgets('큰 글자와 좁은 화면에서 가상 MDD 그래프를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: MarketHistoryView(result: OfflineDemoData.priceHistory),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('완전 가상 가격 그래프'), findsOneWidget);
    expect(find.byType(ComparisonLineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그래프는 선택할 때만 요청하고 실패해도 요약을 변경하지 않는다', (tester) async {
    var calls = 0;
    final client = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(
          utf8.encode(
            '{"error":{"code":"MARKET_DATA_UNAVAILABLE","message":"unavailable","field_errors":[],"request_id":"qa"}}',
          ),
          503,
        );
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketHistoryPanel(
            client: client,
            summary: OfflineDemoData.marketRisk,
            requestedStart: DateTime(2026, 7, 1),
            requestedEnd: DateTime(2026, 9, 29),
          ),
        ),
      ),
    );
    expect(calls, 0);
    await tester.tap(find.text('과거 가격과 MDD 그래프 보기'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('가격 그래프 다시 요청'), findsOneWidget);
    expect(find.textContaining('위험 요약은 유지됩니다'), findsOneWidget);
  });
}
