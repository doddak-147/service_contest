import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/features/foundation/presentation/widgets/risk_lens_illustration.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('좁은 홈 화면에 렌즈 일러스트와 체험 진입을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiClient = ApiClient(
      client: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(apiClient: apiClient),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RiskLensIllustration), findsOneWidget);
    await tester.ensureVisible(find.text('오프라인 체험 · 완전 가상'));
    expect(find.text('오프라인 체험 · 완전 가상'), findsOneWidget);
  });
}
