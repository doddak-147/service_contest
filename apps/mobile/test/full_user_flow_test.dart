import 'dart:convert';

import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('홈에서 금융체력·종목 위험·결합 Report·설명까지 완료한다', (tester) async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return switch (request.url.path) {
          '/health' => _jsonResponse({'status': 'ok'}),
          '/api/v1/financial-health/analyze' => _jsonResponse(
            _financialHealthResponse,
          ),
          '/api/v1/market-risk/KRX/005930' => _jsonResponse(
            _marketRiskResponse,
          ),
          '/api/v1/combined-analyses' => _handleCombinedRequest(request),
          '/api/v1/explanations' => _handleExplanationRequest(request),
          _ => _jsonResponse({
            'error': {
              'code': 'INTERNAL_ERROR',
              'message': 'unexpected test path',
              'field_errors': <Object>[],
              'request_id': 'flow-test',
            },
          }, statusCode: 500),
        };
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(apiClient: apiClient),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('연결됨'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('개인 금융체력 분석하기'));
    await tester.pump();
    await tester.tap(find.text('개인 금융체력 분석하기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('금융체력 계산하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('금융체력 계산하기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('FINANCIAL HEALTH 결과'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1,100,000원'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('종목 선택 후 결합 Report 만들기'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('종목 선택 후 결합 Report 만들기'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('삼성전자 (005930)'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('삼성전자 (005930)'));
    await tester.pumpAndSettle();
    expect(find.text('과거 위험 핵심 지표'), findsOneWidget);

    final combinedButton = find.widgetWithText(
      FilledButton,
      '개인 × 종목 결합 Report 보기',
    );
    await tester.scrollUntilVisible(
      combinedButton,
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(combinedButton);
    await tester.pump();
    await tester.tap(combinedButton);
    await tester.pumpAndSettle();

    expect(find.text('개인 × 종목 금융충격 Report'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('검증된 기본 설명'),
      900,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('3,000,000원'), findsWidgets);
    expect(find.textContaining('투자 추천이나 미래 가격 예측이 아닙니다'), findsOneWidget);
    expect(
      requestedPaths,
      containsAllInOrder([
        '/health',
        '/api/v1/financial-health/analyze',
        '/api/v1/market-risk/KRX/005930',
        '/api/v1/combined-analyses',
        '/api/v1/explanations',
      ]),
    );
  });
}

http.Response _handleCombinedRequest(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  final profile = body['financial_profile'] as Map<String, dynamic>;
  expect(profile['planned_investment_krw'], 10000000);
  expect(profile['equity_amount_krw'], 6000000);
  expect((body['instrument'] as Map<String, dynamic>)['symbol'], '005930');
  return _jsonResponse(_combinedResponse);
}

http.Response _handleExplanationRequest(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  expect(body['scenario_key'], 'historical_mdd');
  expect(body['investment_loss_krw'], 3000000);
  expect(body.containsKey('financial_profile'), isFalse);
  expect(body.containsKey('monthly_income_krw'), isFalse);
  return _jsonResponse({
    'source': 'template',
    'summary': '과거 최대낙폭 가정의 예상 투자손실은 3,000,000원입니다.',
    'caution': '가정된 가격 충격이며 투자 추천이나 미래 가격 예측이 아닙니다.',
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

const _financialHealthResponse = {
  'monthly_surplus_krw': 1100000,
  'emergency_runway_months': 2.631579,
  'leverage_ratio': 0.4,
  'estimated_monthly_interest_krw': 20000,
  'reported_total_debt_krw': 14000000,
  'unavailable_reasons': <String>[],
};

const _instrument = {
  'symbol': '005930',
  'market': 'KRX',
  'name': '삼성전자',
  'currency': 'KRW',
};

const _marketRiskResponse = {
  'instrument': _instrument,
  'period_start': '2025-09-18',
  'period_end': '2026-09-18',
  'data_as_of': '2026-09-18',
  'data_source': 'fake_provider',
  'observation_count': 252,
  'period_return_rate': 0.1,
  'annualized_volatility': 0.2,
  'max_drawdown_rate': -0.3,
  'peak_date': '2025-11-03',
  'trough_date': '2026-03-02',
  'recovery_date': null,
  'warnings': <String>[],
};

final _combinedResponse = {
  'request_id': 'full-flow-test',
  'calculated_at': '2026-09-18T12:00:00Z',
  'calculation_version': '1.0.0',
  'financial_health': _financialHealthResponse,
  'market_risk': _marketRiskResponse,
  'mdd_impact': _scenario('historical_mdd', '과거 최대낙폭 재현', -0.3),
  'scenarios': [
    _scenario('up_20', '20% 상승', 0.2),
    _scenario('flat', '보합', 0),
    _scenario('down_10', '10% 하락', -0.1),
    _scenario('down_20', '20% 하락', -0.2),
    _scenario('down_30', '30% 하락', -0.3),
    _scenario('down_40', '40% 하락', -0.4),
    _scenario('down_50', '50% 하락', -0.5),
    _scenario('historical_mdd', '과거 최대낙폭 재현', -0.3),
  ],
  'warnings': <String>[],
  'disclaimer': '교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다. 과거 성과는 미래 결과를 보장하지 않습니다.',
};

Map<String, dynamic> _scenario(String key, String label, double rate) {
  final pnl = (10000000 * rate).round();
  final loss = pnl < 0 ? -pnl : 0;
  return {
    'scenario_key': key,
    'label': label,
    'assumed_return_rate': rate,
    'projected_investment_value_krw': 10000000 + pnl,
    'investment_pnl_krw': pnl,
    'investment_loss_krw': loss,
    'reported_total_debt_krw': 14000000,
    'net_investment_equity_krw': 6000000 + pnl,
    'loss_to_equity_ratio': loss / 6000000,
    'loss_to_emergency_fund_ratio': loss / 5000000,
    'loss_to_monthly_fixed_expenses': loss / 1500000,
    'estimated_annual_interest_krw': 240000,
    'estimated_monthly_interest_krw': 20000,
    'recovery_required_rate': loss / (10000000 - loss),
    'unavailable_reasons': <String>[],
  };
}
