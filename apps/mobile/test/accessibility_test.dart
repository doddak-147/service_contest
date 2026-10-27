import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('홈 화면은 Android 접근성 터치·레이블·대비 기준을 만족한다', (tester) async {
    final handle = tester.ensureSemantics();
    final apiClient = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"status":"ok"}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(apiClient.close);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(apiClient: apiClient),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('큰 글자에서도 홈의 주요 시작 버튼을 사용할 수 있다', (tester) async {
    final apiClient = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"status":"ok"}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(apiClient.close);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HomeScreen(apiClient: apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('가상 예시로 체험'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('가상 예시로 체험'), findsOneWidget);
    expect(find.text('내 값으로 시작'), findsOneWidget);
  });
}
