import 'package:financial_shock_preview/features/combined_report/presentation/widgets/capital_structure_chart.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('가상 손실 전후 가치와 유지되는 차입 원금을 보여준다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: CapitalStructureChart(
              profile: OfflineDemoData.profile,
              scenario: OfflineDemoData.mddImpact,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('손실 전후 자금 구조'), findsOneWidget);
    expect(find.text('10,000,000원'), findsOneWidget);
    expect(find.text('7,000,000원'), findsOneWidget);
    expect(find.textContaining('차입 원금 4,000,000원 유지'), findsOneWidget);
  });

  testWidgets('순투자지분이 음수여도 막대가 넘치지 않고 경고를 표시한다', (tester) async {
    const totalLoss = ScenarioResult(
      scenario_key: ScenarioKeys.custom,
      label: '가상 전액 손실',
      assumed_return_rate: -1,
      projected_investment_value_krw: 0,
      investment_pnl_krw: -10000000,
      investment_loss_krw: 10000000,
      reported_total_debt_krw: 14000000,
      net_investment_equity_krw: -4000000,
      loss_to_equity_ratio: 1.6666666666666667,
      loss_to_emergency_fund_ratio: 2,
      loss_to_monthly_fixed_expenses: 6.666666666666667,
      estimated_annual_interest_krw: 240000,
      estimated_monthly_interest_krw: 20000,
      recovery_required_rate: null,
      unavailable_reasons: ['NO_FINITE_RECOVERY_RATE'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: CapitalStructureChart(
            profile: OfflineDemoData.profile,
            scenario: totalLoss,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('순투자지분 -4,000,000원'), findsOneWidget);
    expect(find.textContaining('순투자지분이 음수입니다'), findsOneWidget);
  });
}
