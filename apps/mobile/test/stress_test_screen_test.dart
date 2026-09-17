import 'dart:async';
import 'dart:convert';

import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/stress_test_screen.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/widgets/stress_test_comparison_card.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/widgets/stress_test_result_card.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('전체 재무정보와 MDD를 보내고 8개 시나리오를 비교한다', (tester) async {
    const profile = FinancialProfileInput(
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
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/stress-tests/analyze');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final sentProfile = body['financial_profile'] as Map<String, dynamic>;
        expect(sentProfile['emergency_fund_krw'], 5000000);
        expect(sentProfile['existing_loan_balance_krw'], 10000000);
        expect(sentProfile['monthly_debt_payment_krw'], 400000);
        expect(body['historical_mdd_rate'], -0.3);
        return http.Response.bytes(
          utf8.encode(jsonEncode(_scenarioResponse())),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StressTestScreen(
          apiClient: apiClient,
          initialProfile: profile,
          historicalMddRate: -0.3,
          historicalMddSource: '테스트 종목',
        ),
      ),
    );

    expect(find.text('금융체력 분석에서 사용한 재무정보를 불러왔습니다.'), findsOneWidget);
    expect(find.textContaining('테스트 종목의 과거 MDD'), findsOneWidget);

    final calculateButton = find.widgetWithText(FilledButton, '금융 충격 계산하기');
    await tester.scrollUntilVisible(
      calculateButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+20%'), findsOneWidget);
    expect(find.text('보합'), findsOneWidget);
    expect(find.text('과거 MDD (-30.0%)'), findsOneWidget);

    await tester.tap(calculateButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('STRESS TEST 결과'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('2,000,000원'), findsOneWidget);
    expect(find.text('비상자금 대비 손실'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('14,000,000원'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(StressTestComparisonCard),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('전체 시나리오 비교'), findsOneWidget);
    expect(find.text('과거 최대낙폭 재현'), findsOneWidget);
  });

  testWidgets('100% 손실과 0인 분모의 계산 불가 사유를 설명한다', (tester) async {
    const result = ScenarioResult(
      scenario_key: ScenarioKeys.historicalMdd,
      label: '과거 최대낙폭 재현',
      assumed_return_rate: -1,
      projected_investment_value_krw: 0,
      investment_pnl_krw: -10000000,
      investment_loss_krw: 10000000,
      reported_total_debt_krw: 4000000,
      net_investment_equity_krw: -4000000,
      loss_to_equity_ratio: 1.666667,
      loss_to_emergency_fund_ratio: null,
      loss_to_monthly_fixed_expenses: null,
      estimated_annual_interest_krw: 240000,
      estimated_monthly_interest_krw: 20000,
      recovery_required_rate: null,
      unavailable_reasons: [
        'ZERO_EMERGENCY_FUND',
        'ZERO_FIXED_EXPENSES',
        'NO_FINITE_RECOVERY_RATE',
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StressTestResultCard(result: result),
          ),
        ),
      ),
    );

    expect(find.text('유한한 상승률로 회복 불가'), findsOneWidget);
    expect(find.textContaining('비상자금이 0원이라'), findsOneWidget);
    expect(find.textContaining('월 고정지출이 0원이라'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('계산 근거 보기'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('계산 근거 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('예상 손실 = 투자 예정금액'), findsOneWidget);
  });

  testWidgets('입력 수정 후 늦게 도착한 이전 결과를 표시하지 않는다', (tester) async {
    final response = Completer<http.Response>();
    final apiClient = ApiClient(client: MockClient((_) => response.future));
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StressTestScreen(apiClient: apiClient),
      ),
    );

    final calculateButton = find.widgetWithText(FilledButton, '금융 충격 계산하기');
    await tester.scrollUntilVisible(
      calculateButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(calculateButton);
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '월 소득'), '3500000');

    response.complete(
      http.Response.bytes(
        utf8.encode(jsonEncode(_scenarioResponse())),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STRESS TEST 결과'), findsNothing);
    expect(find.byType(StressTestResultCard), findsNothing);
  });
}

List<Map<String, dynamic>> _scenarioResponse() {
  const scenarios = [
    (ScenarioKeys.up20, '20% 상승', 0.2),
    (ScenarioKeys.flat, '보합', 0.0),
    (ScenarioKeys.down10, '10% 하락', -0.1),
    (ScenarioKeys.down20, '20% 하락', -0.2),
    (ScenarioKeys.down30, '30% 하락', -0.3),
    (ScenarioKeys.down40, '40% 하락', -0.4),
    (ScenarioKeys.down50, '50% 하락', -0.5),
    (ScenarioKeys.historicalMdd, '과거 최대낙폭 재현', -0.3),
  ];

  return scenarios
      .map((scenario) {
        final (key, label, rate) = scenario;
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
      })
      .toList(growable: false);
}
