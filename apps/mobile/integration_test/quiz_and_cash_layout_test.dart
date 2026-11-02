import 'package:financial_shock_preview/features/foundation/models/risk_lessons.dart';
import 'package:financial_shock_preview/features/foundation/presentation/risk_learning_screen.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/cash_flow_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('현금흐름 입력·상환 방식·주가 환율 선택의 잘림을 확인한다', (tester) async {
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
    await _tap(tester, find.text('투자용 대출 상환 가정'));
    await _tap(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('매월 같은 원금 분할상환').last);
    await tester.pumpAndSettle();
    final income = find.byKey(const ValueKey('cash-input-소득 감소율'));
    await _reveal(tester, income);
    expect(tester.widget<TextField>(income).controller!.text, '0');
    await _tap(tester, find.text('주가·환율 평가 충격'));
    await _tap(tester, find.text('달러 자산 가정'));
    final price = find.byKey(const ValueKey('cash-input-주가 변화율'));
    await _reveal(tester, price);
    expect(tester.widget<TextField>(price).controller!.text, '0');
    await _reveal(tester, find.byKey(const ValueKey('cash-input-원/달러 환율 변화율')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('정답 오답 표시와 다섯 문제 완료를 휴대폰에서 확인한다', (tester) async {
    await _show(tester, const RiskLearningScreen(offlineSeed: 17));
    final questions = offlineRiskQuiz(seed: 17).questions;
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final selected = i == 0 ? (q.correct_index + 1) % 3 : q.correct_index;
      await _tap(tester, find.text(q.options[selected]));
      await _tap(tester, find.text('정답 확인'));
      await _reveal(tester, find.text(i == 0 ? '오답입니다.' : '정답입니다!'));
      if (i == 0) await _reveal(tester, find.text('내 선택 · 오답'));
      await _tap(tester, find.text(i == 4 ? '새 5문제 시작' : '다음 문제'));
    }
    expect(find.textContaining('1/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('새 문제 구성 API를 휴대폰에서 호출한다', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    await _show(tester, RiskLearningScreen(apiClient: client));
    await _tap(tester, find.text('AI로 새 5문제 만들기'));
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('AI로 새 5문제 만들기').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('1/5'), findsOneWidget);
    expect(find.textContaining('문제 생성 서버에 연결할 수 없어'), findsNothing);
    if (const bool.fromEnvironment('EXPECT_LLM')) {
      expect(find.textContaining('AI 상황 문구'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 280, scrollable: scroll);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}
