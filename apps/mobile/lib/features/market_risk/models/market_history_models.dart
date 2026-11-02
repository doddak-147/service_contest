// ignore_for_file: non_constant_identifier_names
import 'market_risk_models.dart';

class MarketPricePoint {
  const MarketPricePoint({
    required this.date,
    required this.krw_price_index,
    required this.usd_price_index,
    required this.fx_rate_as_of,
  });
  final String date;
  final double krw_price_index;
  final double? usd_price_index;
  final String? fx_rate_as_of;
  factory MarketPricePoint.fromJson(Map<String, dynamic> json) {
    final krw = (json['krw_price_index'] as num).toDouble();
    final usd = (json['usd_price_index'] as num?)?.toDouble();
    if (!krw.isFinite || (usd != null && !usd.isFinite)) {
      throw const FormatException('가격 지수가 유한하지 않습니다.');
    }
    return MarketPricePoint(
      date: json['date'] as String,
      krw_price_index: krw,
      usd_price_index: usd,
      fx_rate_as_of: json['fx_rate_as_of'] as String?,
    );
  }
}

class MarketPriceHistoryResult {
  const MarketPriceHistoryResult({
    required this.market_risk,
    required this.points,
  });
  final MarketRiskResult market_risk;
  final List<MarketPricePoint> points;
  factory MarketPriceHistoryResult.fromJson(Map<String, dynamic> json) {
    final risk = MarketRiskResult.fromJson(
      json['market_risk'] as Map<String, dynamic>,
    );
    final points = (json['points'] as List)
        .map((p) => MarketPricePoint.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
    if (points.isNotEmpty && points.length != risk.observation_count) {
      throw const FormatException('관측치 수가 일치하지 않습니다.');
    }
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1].date.compareTo(points[i].date) >= 0) {
        throw const FormatException('가격 날짜가 오름차순이 아닙니다.');
      }
    }
    return MarketPriceHistoryResult(market_risk: risk, points: points);
  }
}
