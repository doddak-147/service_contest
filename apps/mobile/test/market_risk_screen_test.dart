import 'dart:async';
import 'dart:convert';

import 'package:financial_shock_preview/features/market_risk/models/market_risk_models.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/market_risk_screen.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/widgets/market_risk_card.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('MarketRiskScreen renders search input and popular chips', (
    tester,
  ) async {
    final apiClient = ApiClient(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MarketRiskScreen(apiClient: apiClient),
      ),
    );

    expect(find.text('종목 과거 위험 분석'), findsOneWidget);
    expect(find.text('과거 위험 분석이란?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('삼성전자 (005930)'), findsOneWidget);
    expect(find.text('SK하이닉스 (000660)'), findsOneWidget);
  });

  testWidgets('Selecting a popular stock fetches and displays MarketRiskCard', (
    tester,
  ) async {
    final mockRiskJson = {
      'instrument': {
        'symbol': '005930',
        'market': 'KRX',
        'name': '삼성전자',
        'currency': 'KRW',
      },
      'period_start': '2025-01-01',
      'period_end': '2026-01-01',
      'data_as_of': '2026-01-01',
      'data_source': 'fake_provider',
      'observation_count': 250,
      'period_return_rate': 0.155,
      'annualized_volatility': 0.223,
      'max_drawdown_rate': -0.285,
      'peak_date': '2025-04-10',
      'trough_date': '2025-08-15',
      'recovery_date': '2025-11-20',
      'warnings': [],
    };

    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.contains('/market-risk/')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(mockRiskJson)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MarketRiskScreen(apiClient: apiClient),
      ),
    );

    // Tap popular chip
    await tester.tap(find.text('삼성전자 (005930)'));
    await tester.pump(); // Start loading
    await tester.pump(const Duration(milliseconds: 100)); // Complete fetch

    expect(find.byType(MarketRiskCard), findsOneWidget);
    expect(find.text('최대낙폭 (MDD)'), findsOneWidget);
    expect(find.text('-28.50%'), findsOneWidget);
    expect(find.text('+15.50%'), findsOneWidget);
    expect(find.text('22.30%'), findsOneWidget);
    expect(find.text('2025-04-10'), findsOneWidget);
    expect(find.text('2025-08-15'), findsOneWidget);
    expect(find.text('2025-11-20'), findsOneWidget);
    expect(find.text('fake_provider'), findsOneWidget);
  });

  testWidgets('검색 결과를 선택해 해당 종목 위험을 조회한다', (tester) async {
    final riskJson = {
      'instrument': {
        'symbol': '001040',
        'market': 'KRX',
        'name': 'CJ',
        'currency': 'KRW',
      },
      'period_start': '2025-01-01',
      'period_end': '2026-01-01',
      'data_as_of': '2026-01-01',
      'data_source': 'fake_provider',
      'observation_count': 250,
      'period_return_rate': 0.1,
      'annualized_volatility': 0.2,
      'max_drawdown_rate': -0.3,
      'peak_date': '2025-02-01',
      'trough_date': '2025-03-01',
      'recovery_date': null,
      'warnings': <String>[],
    };
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/instruments/search') {
          expect(request.url.queryParameters['q'], 'CJ');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'symbol': '001040',
                  'market': 'KRX',
                  'name': 'CJ',
                  'currency': 'KRW',
                },
              ]),
            ),
            200,
          );
        }
        return http.Response.bytes(utf8.encode(jsonEncode(riskJson)), 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MarketRiskScreen(apiClient: apiClient),
      ),
    );

    await tester.enterText(find.byType(TextField), 'CJ');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'CJ'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'CJ'));
    await tester.pumpAndSettle();

    expect(find.byType(MarketRiskCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MarketRiskCard),
        matching: find.text('CJ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MarketRiskCard displays null / unrecovered states correctly', (
    tester,
  ) async {
    const result = MarketRiskResult(
      instrument: Instrument(
        symbol: 'CRASH',
        market: 'KRX',
        name: '테스트폭락주',
        currency: 'KRW',
      ),
      period_start: '2025-01-01',
      period_end: '2025-06-01',
      data_as_of: '2025-06-01',
      data_source: 'fake_provider',
      observation_count: 100,
      period_return_rate: -0.40,
      annualized_volatility: null,
      max_drawdown_rate: -0.40,
      peak_date: '2025-01-05',
      trough_date: '2025-03-20',
      recovery_date: null,
      warnings: ['INSUFFICIENT_PRICE_DATA'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: Scaffold(
          body: SingleChildScrollView(child: MarketRiskCard(result: result)),
        ),
      ),
    );

    expect(find.text('테스트폭락주'), findsOneWidget);
    expect(find.text('-40.00%'), findsNWidgets(2)); // return and MDD
    expect(find.text('계산 불가'), findsOneWidget); // volatility is null
    expect(find.text('미회복 (기간 내 최고점 미달)'), findsOneWidget);
    expect(find.text('주의: 관측치가 부족해 일부 지표를 계산하지 못했습니다.'), findsOneWidget);
    expect(find.textContaining('과거 데이터는 미래 결과를 보장하지 않습니다'), findsOneWidget);
  });

  testWidgets('조회 실패 시 이전 종목 결과를 다시 표시하지 않는다', (tester) async {
    final samsungResult = {
      'instrument': {
        'symbol': '005930',
        'market': 'KRX',
        'name': '삼성전자',
        'currency': 'KRW',
      },
      'period_start': '2025-01-01',
      'period_end': '2026-01-01',
      'data_as_of': '2026-01-01',
      'data_source': 'fake_provider',
      'observation_count': 250,
      'period_return_rate': 0.1,
      'annualized_volatility': 0.2,
      'max_drawdown_rate': -0.3,
      'peak_date': '2025-02-01',
      'trough_date': '2025-03-01',
      'recovery_date': null,
      'warnings': <String>[],
    };
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/005930')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(samsungResult)),
            200,
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'MARKET_DATA_UNAVAILABLE',
                'message': '주가 데이터 제공자와 통신할 수 없습니다.',
                'field_errors': <Object>[],
                'request_id': 'test-request-id',
              },
            }),
          ),
          503,
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MarketRiskScreen(apiClient: apiClient),
      ),
    );

    await tester.tap(find.text('삼성전자 (005930)'));
    await tester.pumpAndSettle();
    expect(find.byType(MarketRiskCard), findsOneWidget);

    await tester.tap(find.text('SK하이닉스 (000660)'));
    await tester.pumpAndSettle();

    expect(find.byType(MarketRiskCard), findsNothing);
    expect(find.text('주가 데이터 제공자와 통신할 수 없습니다.'), findsOneWidget);
    expect(find.text('재시도'), findsOneWidget);
  });

  testWidgets('늦게 도착한 이전 요청이 최신 종목 결과를 덮어쓰지 않는다', (tester) async {
    final samsungResponse = Completer<http.Response>();
    final hynixResponse = Completer<http.Response>();

    Map<String, dynamic> result(String symbol, String name) => {
      'instrument': {
        'symbol': symbol,
        'market': 'KRX',
        'name': name,
        'currency': 'KRW',
      },
      'period_start': '2025-01-01',
      'period_end': '2026-01-01',
      'data_as_of': '2026-01-01',
      'data_source': 'fake_provider',
      'observation_count': 250,
      'period_return_rate': 0.1,
      'annualized_volatility': 0.2,
      'max_drawdown_rate': -0.2,
      'peak_date': '2025-02-01',
      'trough_date': '2025-03-01',
      'recovery_date': null,
      'warnings': <String>[],
    };

    final apiClient = ApiClient(
      client: MockClient((request) {
        if (request.url.path.endsWith('/005930')) {
          return samsungResponse.future;
        }
        return hynixResponse.future;
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MarketRiskScreen(apiClient: apiClient),
      ),
    );

    await tester.tap(find.text('삼성전자 (005930)'));
    await tester.pump();
    await tester.tap(find.text('SK하이닉스 (000660)'));
    await tester.pump();

    hynixResponse.complete(
      http.Response.bytes(
        utf8.encode(jsonEncode(result('000660', 'SK하이닉스'))),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MarketRiskCard),
        matching: find.text('SK하이닉스'),
      ),
      findsOneWidget,
    );

    samsungResponse.complete(
      http.Response.bytes(
        utf8.encode(jsonEncode(result('005930', '삼성전자'))),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MarketRiskCard),
        matching: find.text('SK하이닉스'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MarketRiskCard),
        matching: find.text('삼성전자'),
      ),
      findsNothing,
    );
  });

  testWidgets('하락이 없으면 미회복 대신 하락 구간 없음으로 표시한다', (tester) async {
    const result = MarketRiskResult(
      instrument: Instrument(
        symbol: 'GROWTH',
        market: 'KRX',
        name: '테스트상승주',
        currency: 'KRW',
      ),
      period_start: '2025-01-01',
      period_end: '2025-06-01',
      data_as_of: '2025-06-01',
      data_source: 'fake_provider',
      observation_count: 100,
      period_return_rate: 0.2,
      annualized_volatility: 0.1,
      max_drawdown_rate: 0,
      peak_date: null,
      trough_date: null,
      recovery_date: null,
      warnings: <String>[],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MarketRiskCard(result: result)),
        ),
      ),
    );

    expect(find.text('해당 없음 (하락 구간 없음)'), findsOneWidget);
    expect(find.textContaining('미회복'), findsNothing);
  });
}
