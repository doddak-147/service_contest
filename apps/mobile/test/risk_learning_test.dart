import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_shock_preview/features/foundation/presentation/risk_learning_screen.dart';
import 'package:financial_shock_preview/features/foundation/models/risk_lessons.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';

void main() {
  test('가상 사례의 회복률·환율·누적 이자 답이 수학적 관계와 일치한다', () {
    expect(.5 / (1 - .5), 1);
    expect((1 + 0) * (1 - .1) - 1, closeTo(-.1, .000001));
    expect(10000000 * .06 / 12 * 6, 300000);
    expect(riskLessons[0].options[riskLessons[0].correctIndex], '100% 상승');
    expect(riskLessons[1].options[riskLessons[1].correctIndex], '10% 감소');
    expect(riskLessons[2].options[riskLessons[2].correctIndex], '30만 원');
  });
  testWidgets('선택 후 근거를 보고 모든 사례를 진행한 뒤 다시 시작한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RiskLearningScreen()),
    );
    for (var i = 0; i < riskLessons.length; i++) {
      final lesson = riskLessons[i];
      final check = find.widgetWithText(FilledButton, '계산 근거 확인');
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text(lesson.options.first),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(lesson.options.first));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        check,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text(lesson.formula), findsOneWidget);
      final next = find.text(
        i == riskLessons.length - 1 ? '처음부터 다시 체험' : '다음 사례',
      );
      await tester.scrollUntilVisible(
        next,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('1/4'), findsOneWidget);
    expect(find.text(riskLessons.first.formula), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('큰 글자와 좁은 화면에서도 문제와 선택지가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const RiskLearningScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
