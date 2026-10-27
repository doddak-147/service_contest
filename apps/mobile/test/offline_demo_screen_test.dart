import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('고정 가상 사례의 금액이 서로 일치한다', () {
    const profile = OfflineDemoData.profile;
    const financialHealth = OfflineDemoData.financialHealth;
    const marketRisk = OfflineDemoData.marketRisk;
    const mddImpact = OfflineDemoData.mddImpact;
    // Avoid duplicating financial logic in the app: only verify fixture consistency.
    expect(
      profile.equity_amount_krw + profile.borrowed_amount_krw,
      profile.planned_investment_krw,
    );
    expect(
      financialHealth.monthly_surplus_krw,
      profile.monthly_income_krw -
          profile.monthly_fixed_expenses_krw -
          profile.monthly_debt_payment_krw,
    );
    expect(marketRisk.data_source, 'fictional_demo');
    expect(marketRisk.instrument.market, '가상 시장');
    expect(mddImpact.investment_loss_krw, 3000000);
    expect(
      mddImpact.projected_investment_value_krw,
      profile.planned_investment_krw - mddImpact.investment_loss_krw,
    );
    for (final scenario in [...OfflineDemoData.scenarios, mddImpact]) {
      expect(
        scenario.projected_investment_value_krw,
        profile.planned_investment_krw + scenario.investment_pnl_krw,
      );
      expect(
        scenario.net_investment_equity_krw,
        scenario.projected_investment_value_krw - profile.borrowed_amount_krw,
      );
      expect(
        scenario.investment_loss_krw,
        scenario.investment_pnl_krw < 0 ? -scenario.investment_pnl_krw : 0,
      );
    }
  });

  testWidgets('서버가 없어도 오프라인 체험 전 단계를 보고 API 요청은 하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response('{"status":"unavailable"}', 503);
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
    await tester.ensureVisible(find.text('오프라인 체험 · 완전 가상'));
    await tester.tap(find.text('오프라인 체험 · 완전 가상'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('완전 가상 데이터'), findsOneWidget);
    expect(find.text('가상 재무 입력'), findsOneWidget);

    await tester.tap(find.text('가상 종목 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('가상기업 A'), findsOneWidget);
    expect(find.text('가상 예시 데이터'), findsOneWidget);
    expect(find.text('가상 구간 MDD'), findsOneWidget);

    await tester.tap(find.text('결합 결과 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('가상 예시 설명'), findsOneWidget);
    expect(find.textContaining('가상 하락률 30%'), findsOneWidget);
    expect(requestedPaths.where((path) => path.startsWith('/api/')), isEmpty);
  });
}
