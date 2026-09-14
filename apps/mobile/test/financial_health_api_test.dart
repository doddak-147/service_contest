import 'dart:convert';

import 'package:financial_shock_preview/features/financial_health/data/financial_health_api.dart';
import 'package:financial_shock_preview/features/stress_test/models/stress_test_models.dart';
import 'package:financial_shock_preview/shared/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('FinancialHealthApi는 계약 경로로 재무정보를 보내고 결과를 파싱한다', () async {
    final apiClient = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/financial-health/analyze');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['emergency_fund_krw'], 5000000);
        expect(body['existing_loan_balance_krw'], 10000000);
        expect(body['monthly_debt_payment_krw'], 400000);

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'monthly_surplus_krw': 1100000,
              'emergency_runway_months': 2.631579,
              'leverage_ratio': 0.4,
              'estimated_monthly_interest_krw': 20000,
              'reported_total_debt_krw': 14000000,
              'unavailable_reasons': <String>[],
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);

    const profile = FinancialProfileInput(
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

    final result = await FinancialHealthApi(apiClient).analyze(profile);

    expect(result.monthly_surplus_krw, 1100000);
    expect(result.emergency_runway_months, 2.631579);
    expect(result.leverage_ratio, 0.4);
  });
}
