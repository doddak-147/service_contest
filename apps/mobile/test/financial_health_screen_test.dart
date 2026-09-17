import 'dart:convert';

import 'package:financial_shock_preview/features/financial_health/presentation/financial_health_screen.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/stress_test_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('입력값을 전송하고 금융체력 결과를 표시한다', (tester) async {
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/financial-health/analyze');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'monthly_surplus_krw': 1100000,
              'emergency_runway_months': 2.631579,
              'leverage_ratio': 0.4,
              'estimated_monthly_interest_krw': 20000,
              'reported_total_debt_krw': 14000000,
              'unavailable_reasons': <String>[],
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancialHealthScreen(apiClient: apiClient),
      ),
    );

    final calculateButton = find.widgetWithText(FilledButton, '금융체력 계산하기');
    await tester.scrollUntilVisible(
      calculateButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('FINANCIAL HEALTH 결과'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1,100,000원'), findsOneWidget);
    expect(find.text('약 2.63개월'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(find.text('14,000,000원'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('이 정보로 Stress Test 진행'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('이 정보로 Stress Test 진행'));
    await tester.pumpAndSettle();

    final stressTestScreen = tester.widget<StressTestScreen>(
      find.byType(StressTestScreen),
    );
    expect(stressTestScreen.initialProfile?.emergency_fund_krw, 5000000);
    expect(
      stressTestScreen.initialProfile?.existing_loan_balance_krw,
      10000000,
    );
    expect(stressTestScreen.initialProfile?.monthly_debt_payment_krw, 400000);
  });

  testWidgets('서버 필드 오류를 쉬운 한국어로 표시하고 결과를 숨긴다', (tester) async {
    final apiClient = ApiClient(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': '입력값을 확인해 주세요.',
                'field_errors': [
                  {
                    'field': 'equity_amount_krw',
                    'reason': 'INVESTMENT_SUM_MISMATCH',
                  },
                ],
                'request_id': 'test-request-id',
              },
            }),
          ),
          422,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FinancialHealthScreen(apiClient: apiClient),
      ),
    );

    final calculateButton = find.widgetWithText(FilledButton, '금융체력 계산하기');
    await tester.scrollUntilVisible(
      calculateButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();

    expect(find.text('자기자본과 투자용 차입금의 합이 총 투자 예정금액과 같아야 합니다.'), findsOneWidget);
    expect(find.text('FINANCIAL HEALTH 결과'), findsNothing);
  });
}
