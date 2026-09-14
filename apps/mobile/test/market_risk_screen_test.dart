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
      warnings: ['CUSTOM_WARNING'],
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
    expect(find.text('주의: CUSTOM_WARNING'), findsOneWidget);
    expect(find.textContaining('과거 데이터는 미래 결과를 보장하지 않습니다'), findsOneWidget);
  });
}
