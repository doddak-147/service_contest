import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:financial_shock_preview/features/foundation/presentation/risk_learning_screen.dart';
import 'package:financial_shock_preview/features/foundation/models/risk_lessons.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('가상 문제의 정답과 다섯 문제 구성이 일치한다', () {
    expect(.5 / (1 - .5), 1);
    expect((1 + 0) * (1 - .1) - 1, closeTo(-.1, .000001));
    expect(10000000 * .06 / 12 * 6, 300000);
    expect(riskLessons[0].options[riskLessons[0].correct_index], '100% 상승');
    expect(riskLessons[1].options[riskLessons[1].correct_index], '10% 감소');
    expect(riskLessons[2].options[riskLessons[2].correct_index], '30만 원');
    expect(3000000 - 1500000 - 400000 - 20000, 1080000);
    expect(6000000 * (.08 - .06) / 12, closeTo(10000, .0001));
    final round = offlineRiskQuiz(seed: 17);
    expect(round.questions.length, 5);
    expect(round.questions.map((q) => q.topic).toSet().length, 5);
    expect(
      offlineRiskQuiz(seed: 9).questions.map((q) => q.topic).toList(),
      isNot(round.questions.map((q) => q.topic).toList()),
    );
  });

  testWidgets('정답·오답을 표시하며 다섯 문제를 진행한 뒤 새 묶음을 시작한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const RiskLearningScreen(offlineSeed: 17),
      ),
    );
    final questions = offlineRiskQuiz(seed: 17).questions;
    for (var i = 0; i < questions.length; i++) {
      final lesson = questions[i];
      final check = find.widgetWithText(FilledButton, '정답 확인');
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      final selected = i.isEven
          ? lesson.correct_index
          : (lesson.correct_index + 1) % 3;
      await reveal(tester, find.text(lesson.options[selected]));
      await tester.tap(find.text(lesson.options[selected]));
      await tester.pumpAndSettle();
      await reveal(tester, check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('정답'));
      expect(find.text('정답'), findsOneWidget);
      if (i.isOdd) {
        await reveal(tester, find.text('내 선택 · 오답'));
        expect(find.text('내 선택 · 오답'), findsOneWidget);
      }
      await reveal(tester, find.text(lesson.formula));
      expect(find.text(lesson.formula), findsOneWidget);
      expect(find.text(i.isEven ? '정답입니다!' : '오답입니다.'), findsOneWidget);
      final next = find.text(i == 4 ? '새 5문제 시작' : '다음 문제');
      await reveal(tester, next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('1/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [false, true]) {
    testWidgets('새 문제 API 연결과 실패 시 자체 문제 유지: 실패=$failure', (tester) async {
      var calls = 0;
      final questions = offlineRiskQuiz(seed: 7).questions;
      final body = {
        'source': 'llm',
        'fallback_reason': null,
        'questions': questions
            .map(
              (q) => {
                'question_id': q.question_id,
                'topic': q.topic,
                'title': q.title,
                'intro': '가상 사례를 함께 살펴봅니다.',
                'prompt': q.prompt,
                'options': q.options,
                'correct_index': q.correct_index,
                'formula': q.formula,
                'explanation': q.explanation,
              },
            )
            .toList(),
      };
      final client = ApiClient(
        client: MockClient((request) async {
          calls++;
          expect(jsonDecode(request.body).keys.toList(), ['seed']);
          return failure
              ? http.Response('{}', 503)
              : http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RiskLearningScreen(apiClient: client, offlineSeed: 17),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('AI로 새 5문제 만들기'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('1/5'), findsOneWidget);
      if (failure) {
        expect(find.textContaining('오프라인 문제로 이어갑니다'), findsOneWidget);
      } else {
        expect(find.textContaining('AI 상황 문구'), findsOneWidget);
        expect(find.text(questions.first.prompt), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

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
        home: const RiskLearningScreen(offlineSeed: 17),
      ),
    );
    await reveal(tester, find.text('정답 확인'));
    expect(tester.takeException(), isNull);
  });
}
