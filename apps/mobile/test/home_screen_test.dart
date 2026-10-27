import 'package:financial_shock_preview/features/foundation/presentation/home_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('홈에서 내 값으로 시작하면 재무 입력칸이 모두 비어 있다', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(apiClient: apiClient),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('내 값으로 시작'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('내 값으로 시작'));
    await tester.pumpAndSettle();

    expect(find.text('내 값으로 입력'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(
      fields.every((field) => field.controller?.text.isEmpty ?? false),
      isTrue,
    );
  });
}
