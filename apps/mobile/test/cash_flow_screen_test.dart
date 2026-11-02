import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:financial_shock_preview/features/offline_demo/cash_flow_fixtures.dart';
import 'package:financial_shock_preview/features/offline_demo/offline_demo_data.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/cash_flow_screen.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:financial_shock_preview/shared/widgets/comparison_line_chart.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('가정 A·B는 조건과 결과를 따로 보관하고 화면을 닫으면 비운다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CashFlowScreen(isOfflineDemo: true),
                ),
              ),
              child: const Text('체험 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('체험 열기'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('가정 A로 보관'));
    await tester.tap(find.text('가정 A로 보관'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('소득−20%·생활비+10%·금리+2%p'));
    await tester.tap(find.text('소득−20%·생활비+10%·금리+2%p'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('가정 B로 보관'));
    await tester.tap(find.text('가정 B로 보관'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('가정 A · B 비교'));
    expect(find.text('가정 A · B 비교'), findsOneWidget);
    await reveal(tester, find.text('달라진 조건 5개'));
    expect(find.text('달라진 조건 5개'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('체험 열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('보관 상태'), findsNothing);
    expect(find.text('가정 A · B 비교'), findsNothing);
  });

  testWidgets('서버 없이 3·6·12개월 가상 현금흐름과 생활 충격을 본다', (tester) async {
    var calls = 0;
    final client = ApiClient(
      client: MockClient((_) async {
        calls++;
        throw StateError('No network');
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CashFlowScreen(isOfflineDemo: true, apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('12개월'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('소득−20%·생활비+10%·금리+2%p'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('생활 충격 · 12개월 결과'));
    expect(find.text('생활 충격 · 12개월 결과'), findsOneWidget);
    await reveal(tester, find.byType(ComparisonLineChart));
    expect(find.text('현금 여력의 변화'), findsOneWidget);
    await tester.ensureVisible(find.text('누적 이자'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('누적 이자'));
    await tester.pumpAndSettle();
    expect(find.text('기간별 누적 투자용 이자'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('현금흐름 API 결과를 표시하고 입력 수정 시 숨긴다', (tester) async {
    var calls = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/v1/stress-tests/cash-flow');
        return http.Response.bytes(
          utf8.encode(CashFlowFixtures.encode(6, false)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CashFlowScreen(
          apiClient: client,
          initialProfile: OfflineDemoData.profile,
          isExampleProfile: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final calculate = find.text('현금흐름 계산하기');
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('생활 충격 · 6개월 결과'));
    expect(find.text('생활 충격 · 6개월 결과'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2200));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('소득 감소율'));
    final income = find.byKey(const ValueKey('cash-input-소득 감소율'));
    await tester.enterText(income, '20');
    await tester.pumpAndSettle();
    expect(find.text('생활 충격 · 6개월 결과'), findsNothing);
    expect(calls, 1);
  });

  testWidgets('늦은 현금흐름 응답이 수정한 입력에 표시되지 않는다', (tester) async {
    final pending = Completer<http.Response>();
    final client = ApiClient(client: MockClient((_) => pending.future));
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CashFlowScreen(
          apiClient: client,
          initialProfile: OfflineDemoData.profile,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final calculate = find.text('현금흐름 계산하기');
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pump();
    final income = find.byKey(const ValueKey('cash-input-소득 감소율'));
    await reveal(tester, income);
    await tester.enterText(income, '10');
    await tester.pump();
    pending.complete(
      http.Response.bytes(utf8.encode(CashFlowFixtures.encode(6, false)), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('생활 충격 · 6개월 결과'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면과 큰 글자에서도 가상 결과가 넘치지 않는다', (tester) async {
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
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const CashFlowScreen(isOfflineDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(ComparisonLineChart));
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면의 큰 글자에서 입력과 대출 상환 선택이 잘리지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
      client: MockClient((_) async => throw StateError('No request')),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: CashFlowScreen(apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('투자용 대출 상환 가정'));
    await tester.tap(find.text('투자용 대출 상환 가정'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(DropdownButtonFormField<String>));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
