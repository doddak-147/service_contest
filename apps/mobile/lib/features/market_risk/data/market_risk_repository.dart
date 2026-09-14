import '../../../shared/api/api_client.dart';
import '../models/market_risk_models.dart';

class MarketRiskRepository {
  const MarketRiskRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Instrument>> searchInstruments(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final encoded = Uri.encodeQueryComponent(trimmed);
    final rawList = await _apiClient.getList(
      '/api/v1/instruments/search?q=$encoded',
    );
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(Instrument.fromJson)
        .toList(growable: false);
  }

  Future<MarketRiskResult> getMarketRisk({
    required String market,
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);
    final encodedMarket = Uri.encodeComponent(market);
    final encodedSymbol = Uri.encodeComponent(symbol);

    final rawJson = await _apiClient.getJson(
      '/api/v1/market-risk/$encodedMarket/$encodedSymbol?start_date=$startStr&end_date=$endStr',
    );
    return MarketRiskResult.fromJson(rawJson);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
