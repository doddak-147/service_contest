import 'dart:convert';

import 'package:financial_shock_preview/features/combined_report/models/combined_report_models.dart';
import 'package:financial_shock_preview/features/combined_report/presentation/widgets/combined_report_view.dart';
import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('홈에서 예시 입력을 수정하면 총 투자금이 자동 계산되어 전송된다', (tester) async {
    int? sentTotal;
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/health') {
          return _jsonResponse({'status': 'ok'});
        }
        if (request.url.path == '/api/v1/financial-health/analyze') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentTotal = body['planned_investment_krw'] as int;
          return _jsonResponse({
            'monthly_surplus_krw': 1100000,
            'emergency_runway_months': 2.631579,
            'leverage_ratio': 4 / 11,
            'estimated_monthly_interest_krw': 20000,
            'reported_total_debt_krw': 14000000,
            'unavailable_reasons': <String>[],
          });
        }
        return _jsonResponse({'error': 'unexpected request'}, statusCode: 404);
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
    final start = find.text('가상 예시로 체험');
    await tester.scrollUntilVisible(
      start,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pumpAndSettle();

    final equity = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == '자기자본',
        )
        .first;
    await tester.scrollUntilVisible(
      equity,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(equity, '7000000');
    await tester.pumpAndSettle();
    expect(find.text('11,000,000원'), findsOneWidget);
    expect(find.widgetWithText(TextField, '총 투자 예정금액'), findsNothing);

    final calculate = find.widgetWithText(FilledButton, '금융체력 계산하기');
    await tester.scrollUntilVisible(
      calculate,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(sentTotal, 11000000);
    await tester.scrollUntilVisible(
      find.text('FINANCIAL HEALTH 결과'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('FINANCIAL HEALTH 결과'), findsOneWidget);
  });

  testWidgets('결합 결과에서 쉬운 설명을 먼저 보고 계산 근거를 펼칠 수 있다', (tester) async {
    final result = CombinedAnalysisResult.fromJson(_combinedResponse());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              children: [
                CombinedReportView(
                  result: result,
                  financialProfile: _profile,
                  explanation: const ExplanationResult(
                    source: 'llm',
                    summary: '가정 손실은 3,000,000원입니다.',
                    caution: '미래 결과를 예측하지 않습니다.',
                  ),
                  explanationError: null,
                  isExplanationLoading: false,
                  onRetryExplanation: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('최근 3개월 관측 구간'), findsOneWidget);
    expect(find.textContaining('전체 과거의 최악을 뜻하지 않습니다'), findsOneWidget);
    expect(find.text('계산 근거와 전체 시나리오 보기'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('AI 쉬운 설명'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('가정 손실은 3,000,000원입니다.'), findsOneWidget);
    final details = find.text('계산 근거와 전체 시나리오 보기');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('과거 MDD 적용 충격'), findsOneWidget);
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

const _profile = FinancialProfileInput(
  monthly_income_krw: 3000000,
  monthly_fixed_expenses_krw: 1500000,
  emergency_fund_krw: 5000000,
  existing_loan_balance_krw: 10000000,
  monthly_debt_payment_krw: 400000,
  planned_investment_krw: 10000000,
  equity_amount_krw: 6000000,
  borrowed_amount_krw: 4000000,
  annual_loan_rate: 0.06,
);

Map<String, dynamic> _combinedResponse() {
  final mdd = {
    'scenario_key': ScenarioKeys.historicalMdd,
    'label': '과거 MDD',
    'assumed_return_rate': -0.3,
    'projected_investment_value_krw': 7000000,
    'investment_pnl_krw': -3000000,
    'investment_loss_krw': 3000000,
    'reported_total_debt_krw': 14000000,
    'net_investment_equity_krw': 3000000,
    'loss_to_equity_ratio': 0.5,
    'loss_to_emergency_fund_ratio': 0.6,
    'loss_to_monthly_fixed_expenses': 2.0,
    'estimated_annual_interest_krw': 240000,
    'estimated_monthly_interest_krw': 20000,
    'recovery_required_rate': 3 / 7,
    'unavailable_reasons': <String>[],
  };
  return {
    'request_id': 'device-test',
    'calculated_at': '2026-10-28T12:00:00Z',
    'calculation_version': '1.0.0',
    'financial_health': {
      'monthly_surplus_krw': 1100000,
      'emergency_runway_months': 2.631579,
      'leverage_ratio': 0.4,
      'estimated_monthly_interest_krw': 20000,
      'reported_total_debt_krw': 14000000,
      'unavailable_reasons': <String>[],
    },
    'market_risk': {
      'instrument': {
        'symbol': 'AAPL',
        'market': 'NASDAQ',
        'name': 'Apple Inc.',
        'currency': 'USD',
      },
      'period_start': '2026-07-01',
      'period_end': '2026-09-29',
      'data_as_of': '2026-09-29',
      'fx_rate_as_of': '2026-09-29',
      'data_source': 'twelve_data+ecb_reference_fx',
      'observation_count': 63,
      'period_return_rate': -0.02,
      'annualized_volatility': 0.29,
      'max_drawdown_rate': -0.3,
      'peak_date': '2026-07-28',
      'trough_date': '2026-09-09',
      'recovery_date': null,
      'warnings': <String>[],
    },
    'mdd_impact': mdd,
    'scenarios': [mdd],
    'warnings': <String>[],
    'disclaimer': '교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다.',
  };
}
