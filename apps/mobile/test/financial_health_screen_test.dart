import 'dart:convert';

import 'package:financial_shock_preview/features/financial_health/presentation/financial_health_screen.dart';
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

    await tester.ensureVisible(find.text('금융체력 계산하기'));
    await tester.tap(find.text('금융체력 계산하기'));
    await tester.pumpAndSettle();

    expect(find.text('1,100,000원'), findsOneWidget);
    expect(find.text('약 2.63개월'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(find.text('14,000,000원'), findsOneWidget);
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

    await tester.ensureVisible(find.text('금융체력 계산하기'));
    await tester.tap(find.text('금융체력 계산하기'));
    await tester.pumpAndSettle();

    expect(find.text('자기자본과 투자용 차입금의 합이 총 투자 예정금액과 같아야 합니다.'), findsOneWidget);
    expect(find.text('FINANCIAL HEALTH 결과'), findsNothing);
  });
}
