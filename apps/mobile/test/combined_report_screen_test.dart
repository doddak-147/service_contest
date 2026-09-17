import 'dart:convert';

import 'package:financial_shock_preview/features/combined_report/presentation/combined_report_screen.dart';
import 'package:financial_shock_preview/features/financial_health/presentation/widgets/financial_health_result_card.dart';
import 'package:financial_shock_preview/features/market_risk/models/market_risk_models.dart';
import 'package:financial_shock_preview/features/market_risk/presentation/widgets/market_risk_card.dart';
import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:financial_shock_preview/features/stress_test/presentation/widgets/stress_test_result_card.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:financial_shock_preview/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('재무정보와 종목을 전송하고 결합 Report를 표시한다', (tester) async {
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/combined-analyses');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final profile = body['financial_profile'] as Map<String, dynamic>;
        final instrument = body['instrument'] as Map<String, dynamic>;
        expect(profile['emergency_fund_krw'], 5000000);
        expect(profile['existing_loan_balance_krw'], 10000000);
        expect(profile['monthly_debt_payment_krw'], 400000);
        expect(instrument['symbol'], '005930');
        expect(body['period_start'], '2025-01-02');
        expect(body['period_end'], '2025-12-30');
        return http.Response.bytes(
          utf8.encode(jsonEncode(_combinedResponse())),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CombinedReportScreen(
          apiClient: apiClient,
          financialProfile: _profile,
          instrument: _instrument,
          periodStart: '2025-01-02',
          periodEnd: '2025-12-30',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FinancialHealthResultCard), findsOneWidget);
    expect(find.byType(MarketRiskCard), findsOneWidget);
    expect(find.byType(StressTestResultCard), findsOneWidget);
    expect(find.text('과거 MDD 적용 충격'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('정적 템플릿 설명'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('예상 투자손실은 3,000,000원'), findsOneWidget);
    expect(find.textContaining('AI를 사용하지 않은 검증 가능한 기본 설명'), findsOneWidget);
    expect(find.textContaining('투자 자문이 아닙니다'), findsOneWidget);
  });

  testWidgets('주가 장애 부분 응답에서도 금융체력과 고정 시나리오를 표시한다', (tester) async {
    final apiClient = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_combinedResponse(marketUnavailable: true))),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CombinedReportScreen(
          apiClient: apiClient,
          financialProfile: _profile,
          instrument: _instrument,
          periodStart: '2025-01-02',
          periodEnd: '2025-12-30',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FinancialHealthResultCard), findsOneWidget);
    expect(find.byType(MarketRiskCard), findsNothing);
    expect(find.byType(StressTestResultCard), findsNothing);
    expect(find.textContaining('주가 데이터 제공자와 통신하지 못해'), findsOneWidget);
    expect(find.textContaining('고정 상승·보합·하락 시나리오'), findsOneWidget);
  });
}

const _profile = FinancialProfileInput(
  monthly_income_krw: 3000000,
  monthly_fixed_expenses_krw: 1500000,
  emergency_fund_krw: 5000000,
  existing_loan_balance_krw: 10000000,
  monthly_debt_payment_krw: 400000,
  planned_investment_krw: 10000000,
  equity_amount_krw: 6000000,
  borrowed_amount_krw: 4000000,
  annual_loan_rate: 0.06,
);

const _instrument = Instrument(
  symbol: '005930',
  market: 'KRX',
  name: '삼성전자',
  currency: 'KRW',
);

Map<String, dynamic> _combinedResponse({bool marketUnavailable = false}) {
  final scenarios = _scenarioResponse(includeHistoricalMdd: !marketUnavailable);
  return {
    'request_id': 'combined-test-request',
    'calculated_at': '2026-09-17T12:00:00Z',
    'calculation_version': '1.0.0',
    'financial_health': {
      'monthly_surplus_krw': 1100000,
      'emergency_runway_months': 2.631579,
      'leverage_ratio': 0.4,
      'estimated_monthly_interest_krw': 20000,
      'reported_total_debt_krw': 14000000,
      'unavailable_reasons': <String>[],
    },
    'market_risk': marketUnavailable
        ? null
        : {
            'instrument': _instrument.toJson(),
            'period_start': '2025-01-02',
            'period_end': '2025-12-30',
            'data_as_of': '2025-12-30',
            'data_source': 'fake_provider',
            'observation_count': 250,
            'period_return_rate': 0.1,
            'annualized_volatility': 0.2,
            'max_drawdown_rate': -0.3,
            'peak_date': '2025-02-01',
            'trough_date': '2025-03-01',
            'recovery_date': null,
            'warnings': <String>[],
          },
    'mdd_impact': marketUnavailable ? null : scenarios.last,
    'scenarios': scenarios,
    'warnings': marketUnavailable ? ['MARKET_DATA_UNAVAILABLE'] : <String>[],
    'disclaimer': '교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다. 과거 성과는 미래 결과를 보장하지 않습니다.',
  };
}

List<Map<String, dynamic>> _scenarioResponse({
  required bool includeHistoricalMdd,
}) {
  final scenarios = <(String, String, double)>[
    (ScenarioKeys.up20, '20% 상승', 0.2),
    (ScenarioKeys.flat, '보합', 0),
    (ScenarioKeys.down10, '10% 하락', -0.1),
    (ScenarioKeys.down20, '20% 하락', -0.2),
    (ScenarioKeys.down30, '30% 하락', -0.3),
    (ScenarioKeys.down40, '40% 하락', -0.4),
    (ScenarioKeys.down50, '50% 하락', -0.5),
    if (includeHistoricalMdd) (ScenarioKeys.historicalMdd, '과거 최대낙폭 재현', -0.3),
  ];

  return scenarios
      .map((scenario) {
        final (key, label, rate) = scenario;
        final pnl = (10000000 * rate).round();
        final loss = pnl < 0 ? -pnl : 0;
        return {
          'scenario_key': key,
          'label': label,
          'assumed_return_rate': rate,
          'projected_investment_value_krw': 10000000 + pnl,
          'investment_pnl_krw': pnl,
          'investment_loss_krw': loss,
          'reported_total_debt_krw': 14000000,
          'net_investment_equity_krw': 6000000 + pnl,
          'loss_to_equity_ratio': loss / 6000000,
          'loss_to_emergency_fund_ratio': loss / 5000000,
          'loss_to_monthly_fixed_expenses': loss / 1500000,
          'estimated_annual_interest_krw': 240000,
          'estimated_monthly_interest_krw': 20000,
          'recovery_required_rate': loss / (10000000 - loss),
          'unavailable_reasons': <String>[],
        };
      })
      .toList(growable: false);
}
