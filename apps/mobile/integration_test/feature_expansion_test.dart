import 'package:financial_shock_preview/features/foundation/models/risk_lessons.dart';
import 'package:financial_shock_preview/features/foundation/presentation/risk_learning_screen.dart';
import 'package:financial_shock_preview/features/market_risk/models/market_risk_models.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/widgets/market_history_view.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/cash_flow_screen.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/widgets/cash_flow_result_view.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:financial_shock_preview/shared/widgets/comparison_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run only against the private local QA API via ADB reverse. No user data/keys.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실제 계산 API로 생활 충격과 A·B 비교를 검증한다', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    await _show(
      tester,
      CashFlowScreen(
        apiClient: client,
        initialProfile: OfflineDemoData.profile,
        isExampleProfile: true,
      ),
    );
    await _tap(tester, find.text('현금흐름 계산하기'));
    await _waitFor(tester, find.text('현금흐름 계산하기'));
    await _reveal(tester, find.byType(CashFlowResultView));
    final before = tester
        .widget<CashFlowResultView>(find.byType(CashFlowResultView))
        .result;
    expect(before.baseline.ending_cash_balance_krw, 11480000);
    expect(before.shocked.total_interest_krw, 120000);
    await _tap(tester, find.text('가정 A로 보관'));
    await _tap(tester, find.text('생활 충격 예시 적용'));
    await _tap(tester, find.text('현금흐름 계산하기'));
    await _waitFor(tester, find.text('현금흐름 계산하기'));
    await _reveal(tester, find.byType(CashFlowResultView));
    final after = tester
        .widget<CashFlowResultView>(find.byType(CashFlowResultView))
        .result;
    expect(after.shocked.monthly_points.first.investment_interest_krw, 26667);
    expect(after.shocked.monthly_points.first.monthly_net_cash_krw, 323333);
    expect(after.shocked.ending_cash_balance_krw, 6939998);
    await _tap(tester, find.text('가정 B로 보관'));
    await _reveal(tester, find.text('달라진 조건 3개'));
    expect(find.text('가정 A · B 비교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('실제 시계열 API의 원화·달러 그래프를 연결한다', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    String day(DateTime value) => value.toIso8601String().substring(0, 10);
    final body = await tester.runAsync(
      () => client.getJson(
        '/api/v1/market-risk/NASDAQ/AAPL?start_date=${day(start)}&end_date=${day(now)}',
      ),
    );
    final summary = MarketRiskResult.fromJson(body!);
    await _show(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: MarketHistoryPanel(
            client: client,
            summary: summary,
            requestedStart: start,
            requestedEnd: now,
          ),
        ),
      ),
    );
    await tester.tap(find.text('과거 가격과 MDD 그래프 보기'));
    await _waitFor(tester, find.byType(MarketHistoryView));
    final history = tester
        .widget<MarketHistoryView>(find.byType(MarketHistoryView))
        .result;
    expect(history.points.length, summary.observation_count);
    expect(history.points.first.krw_price_index, 100);
    expect(history.points.first.usd_price_index, 100);
    expect(find.byType(ComparisonLineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('서버 없이 기간별 가상 현금흐름을 표시한다', (tester) async {
    await _show(tester, const CashFlowScreen(isOfflineDemo: true));
    for (final months in [3, 6, 12]) {
      await _tap(tester, find.text('$months개월'));
      await _reveal(tester, find.byType(CashFlowResultView));
      expect(
        tester
            .widget<CashFlowResultView>(find.byType(CashFlowResultView))
            .result
            .months,
        months,
      );
      expect(find.byType(ComparisonLineChart), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('휴대폰에서 위험 이해 체험 네 사례를 끝까지 진행한다', (tester) async {
    await _show(tester, const RiskLearningScreen(offlineSeed: 17));
    final questions = offlineRiskQuiz(seed: 17).questions;
    for (var index = 0; index < questions.length; index++) {
      final lesson = questions[index];
      await _tap(tester, find.text(lesson.options[lesson.correct_index]));
      await _tap(tester, find.text('정답 확인'));
      await _reveal(tester, find.text(lesson.formula));
      expect(find.text(lesson.formula), findsOneWidget);
      await _tap(
        tester,
        find.text(index == questions.length - 1 ? '새 5문제 시작' : '다음 문제'),
      );
    }
    expect(find.textContaining('1/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 300, scrollable: scrollable);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 160; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (target.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the private QA API response.');
}
