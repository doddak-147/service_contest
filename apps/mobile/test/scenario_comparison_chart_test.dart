import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/widgets/scenario_comparison_chart.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('좁은 화면에서 가상 시나리오 금액을 그래프로 비교한다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: ScenarioComparisonChart(
                results: OfflineDemoData.scenarios,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('시나리오별 손실 비교'), findsOneWidget);
    expect(find.text('주가 -50%'), findsOneWidget);
    expect(find.text('5,000,000원'), findsNWidgets(2));
    expect(find.textContaining('막대 길이는'), findsOneWidget);
  });

  testWidgets('결과가 없으면 그래프를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ScenarioComparisonChart(results: [])),
      ),
    );
    expect(find.text('시나리오별 손실 비교'), findsNothing);
  });
}
