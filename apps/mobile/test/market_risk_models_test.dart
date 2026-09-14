import 'package:flutter_test/flutter_test.dart';
import 'package:financial_shock_preview/features/market_risk/models/market_risk_models.dart';

void main() {
  group('Instrument', () {
    test('serializes to and from json accurately', () {
      final json = {
        'symbol': '005930',
        'market': 'KRX',
        'name': '삼성전자',
        'currency': 'KRW',
      };

      final instrument = Instrument.fromJson(json);
      expect(instrument.symbol, '005930');
      expect(instrument.market, 'KRX');
      expect(instrument.name, '삼성전자');
      expect(instrument.currency, 'KRW');
      expect(instrument.toJson(), json);
    });

    test('equality works based on symbol and market', () {
      const inst1 = Instrument(
        symbol: '005930',
        market: 'KRX',
        name: '삼성전자',
        currency: 'KRW',
      );
      const inst2 = Instrument(
        symbol: '005930',
        market: 'KRX',
        name: '삼성전자 보통주',
        currency: 'KRW',
      );
      expect(inst1, inst2);
    });
  });

  group('MarketRiskResult', () {
    test('parses full json payload according to API_CONTRACT.md', () {
      final json = {
        'instrument': {
          'symbol': '005930',
          'market': 'KRX',
          'name': '삼성전자',
          'currency': 'KRW',
        },
        'period_start': '2023-01-02',
        'period_end': '2025-12-30',
        'data_as_of': '2025-12-30',
        'data_source': 'naver_finance',
        'observation_count': 735,
        'period_return_rate': 0.12,
        'annualized_volatility': 0.24,
        'max_drawdown_rate': -0.31,
        'peak_date': '2024-07-10',
        'trough_date': '2025-04-09',
        'recovery_date': '2025-11-20',
        'warnings': ['INSUFFICIENT_DATA_ALERT'],
      };

      final result = MarketRiskResult.fromJson(json);
      expect(result.instrument.symbol, '005930');
      expect(result.period_start, '2023-01-02');
      expect(result.period_end, '2025-12-30');
      expect(result.data_as_of, '2025-12-30');
      expect(result.data_source, 'naver_finance');
      expect(result.observation_count, 735);
      expect(result.period_return_rate, 0.12);
      expect(result.annualized_volatility, 0.24);
      expect(result.max_drawdown_rate, -0.31);
      expect(result.peak_date, '2024-07-10');
      expect(result.trough_date, '2025-04-09');
      expect(result.recovery_date, '2025-11-20');
      expect(result.warnings, ['INSUFFICIENT_DATA_ALERT']);
    });

    test('handles nullable fields gracefully', () {
      final json = {
        'instrument': {
          'symbol': 'NODATA',
          'market': 'KRX',
          'name': '테스트부족주',
          'currency': 'KRW',
        },
        'period_start': '2024-01-01',
        'period_end': '2024-01-05',
        'data_as_of': '2024-01-05',
        'data_source': 'fake_provider',
        'observation_count': 1,
        'period_return_rate': null,
        'annualized_volatility': null,
        'max_drawdown_rate': null,
        'peak_date': null,
        'trough_date': null,
        'recovery_date': null,
        'warnings': ['INSUFFICIENT_PRICE_DATA'],
      };

      final result = MarketRiskResult.fromJson(json);
      expect(result.period_return_rate, isNull);
      expect(result.annualized_volatility, isNull);
      expect(result.max_drawdown_rate, isNull);
      expect(result.peak_date, isNull);
      expect(result.trough_date, isNull);
      expect(result.recovery_date, isNull);
      expect(result.warnings, ['INSUFFICIENT_PRICE_DATA']);
    });

    test('throws FormatException on malformed json type', () {
      final json = {
        'instrument': 'invalid_string',
        'period_start': '2024-01-01',
      };

      expect(() => MarketRiskResult.fromJson(json), throwsFormatException);
    });
  });
}
