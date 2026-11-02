import 'package:flutter/material.dart';
import '../../../../shared/api/api_client.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/comparison_line_chart.dart';
import '../../models/market_history_models.dart';
import '../../models/market_risk_models.dart';

class MarketHistoryView extends StatelessWidget {
  const MarketHistoryView({required this.result, super.key});
  final MarketPriceHistoryResult result;
  @override
  Widget build(BuildContext context) {
    final risk = result.market_risk;
    final points = result.points;
    if (points.length < 2) return const Text('가격 관측치가 부족해 그래프를 표시하지 않습니다.');
    final markers = <int, String>{};
    for (final entry in {
      '고점': risk.peak_date,
      '저점': risk.trough_date,
      '회복': risk.recovery_date,
    }.entries) {
      final index = points.indexWhere((p) => p.date == entry.value);
      if (index >= 0) {
        markers[index] = [
          if (markers[index] != null) markers[index],
          entry.key,
        ].join(' · ');
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              risk.data_source == 'fictional_demo'
                  ? '완전 가상 가격 그래프'
                  : '과거 가격과 원화 MDD 구간',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '첫 관측값을 100으로 맞췄습니다. 110은 첫날 대비 +10%이며 원화·달러의 가격 단위 차이를 제거한 비교입니다.',
            ),
            if (risk.data_source == 'fictional_demo')
              const Text('곡선·날짜·환율은 전부 가상입니다. 실제 시세를 사용하지 않습니다.'),
            const SizedBox(height: 14),
            ComparisonLineChart(
              title: '원화·달러 기준 가격 변화',
              labels: points.map((p) => p.date).toList(),
              includeZero: false,
              highlightStart: points.indexWhere(
                (p) => p.date == risk.peak_date,
              ),
              highlightEnd: points.indexWhere(
                (p) => p.date == risk.trough_date,
              ),
              series: [
                LineSeries(
                  '원화 기준',
                  AppColors.primary,
                  points.map((p) => p.krw_price_index).toList(),
                ),
                if (points.any((p) => p.usd_price_index != null))
                  LineSeries(
                    '달러 기준',
                    Colors.deepPurple,
                    points.map((p) => p.usd_price_index).toList(),
                  ),
              ],
              unit: '첫 관측=100',
              markers: markers,
            ),
            const SizedBox(height: 10),
            Text(
              '원화 기준 고점 ${risk.peak_date ?? '하락 구간 없음'} · 저점 ${risk.trough_date ?? '해당 없음'}',
            ),
            Text(
              '고점 회복 ${risk.peak_date == null ? '해당 없음' : risk.recovery_date ?? '조회 기간 내 미회복'}',
            ),
            Text(
              '출처: ${switch (risk.data_source) {
                'fictional_demo' => '명시된 가상 사례',
                'twelve_data+ecb_reference_fx' => 'Twelve Data + ECB 참고 환율',
                _ => risk.data_source,
              }}',
            ),
            Text(
              '가격 기준일 ${risk.data_as_of} · 환율 기준일 ${risk.fx_rate_as_of ?? '해당 없음'} · 관측 ${risk.observation_count}개',
            ),
            if (risk.warnings.contains('USD_PRICE_UNAVAILABLE'))
              const Text('달러 기준 일부 관측값이 없어 해당 선을 생략하거나 끊어서 표시합니다.'),
            const Text(
              '음영은 원화 MDD의 고점→저점 구간입니다. 가로축은 관측 순서이며 거래 없는 날짜의 새 값을 만들지 않습니다. 분할 조정·배당 제외 기준으로 미래 가격을 예측하지 않습니다.',
            ),
          ],
        ),
      ),
    );
  }
}

class MarketHistoryPanel extends StatefulWidget {
  const MarketHistoryPanel({
    required this.client,
    required this.summary,
    required this.requestedStart,
    required this.requestedEnd,
    super.key,
  });
  final ApiClient client;
  final MarketRiskResult summary;
  final DateTime requestedStart, requestedEnd;
  @override
  State<MarketHistoryPanel> createState() => _MarketHistoryPanelState();
}

class _MarketHistoryPanelState extends State<MarketHistoryPanel> {
  MarketPriceHistoryResult? _result;
  String? _error;
  bool _loading = false;
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final symbol = Uri.encodeComponent(widget.summary.instrument.symbol);
      final market = Uri.encodeComponent(widget.summary.instrument.market);
      final start = widget.requestedStart.toIso8601String().substring(0, 10);
      final end = widget.requestedEnd.toIso8601String().substring(0, 10);
      final body = await widget.client.getJson(
        '/api/v1/market-risk/$market/$symbol/history?start_date=$start&end_date=$end',
      );
      final result = MarketPriceHistoryResult.fromJson(body);
      final risk = result.market_risk;
      final original = widget.summary;
      if (risk.instrument != original.instrument ||
          risk.instrument.currency != original.instrument.currency ||
          risk.instrument.instrument_type !=
              original.instrument.instrument_type ||
          risk.period_start != original.period_start ||
          risk.period_end != original.period_end ||
          risk.data_as_of != original.data_as_of ||
          risk.fx_rate_as_of != original.fx_rate_as_of ||
          risk.data_source != original.data_source ||
          risk.period_return_rate != original.period_return_rate ||
          risk.annualized_volatility != original.annualized_volatility ||
          risk.max_drawdown_rate != original.max_drawdown_rate ||
          risk.observation_count != original.observation_count ||
          risk.peak_date != original.peak_date ||
          risk.trough_date != original.trough_date ||
          risk.recovery_date != original.recovery_date) {
        throw const FormatException('가격 기준이 달라졌습니다. 종목 위험을 다시 조회해 주세요.');
      }
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              '가격 그래프를 가져올 수 없습니다. 위험 요약은 유지됩니다. 기준일이 달라졌다면 종목을 다시 조회해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_result != null)
        MarketHistoryView(result: _result!)
      else if (_loading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.timeline),
          label: Text(_error == null ? '과거 가격과 MDD 그래프 보기' : '가격 그래프 다시 요청'),
        ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: AppColors.textMuted)),
    ],
  );
}
