import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/market_risk_models.dart';

class MarketRiskCard extends StatelessWidget {
  const MarketRiskCard({required this.result, super.key});

  final MarketRiskResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Long ETF names must remain readable on narrow phone screens.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.instrument.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${result.instrument.symbol} · ${result.instrument.market} · ${result.instrument.currency} · ${result.instrument.instrument_type == 'etf' ? 'ETF' : '주식'}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    result.data_source == 'twelve_data+ecb_reference_fx'
                        ? 'Twelve Data + ECB'
                        : result.data_source == 'fictional_demo'
                        ? '가상 예시 데이터'
                        : result.data_source,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Period & Observation info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.data_source == 'fictional_demo'
                          ? '${result.period_start} ~ ${result.period_end} (가상 날짜 · 가상 관측치 ${result.observation_count}개)'
                          : '${result.period_start} ~ ${result.period_end} (기준일: ${result.data_as_of}, ${result.observation_count}일 관측)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Core 3 Metrics
            Text(
              result.data_source == 'fictional_demo'
                  ? '가상 위험 핵심 지표'
                  : '과거 위험 핵심 지표',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: '기간 수익률',
                    value: _formatPercent(result.period_return_rate),
                    color: _returnColor(result.period_return_rate),
                    description: '시작일 대비 종료일',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: '연환산 변동성',
                    value: _formatPercent(
                      result.annualized_volatility,
                      showSign: false,
                    ),
                    color: AppColors.text,
                    description: '일간 수익률 표준편차 × √252',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MddHighlightTile(
              mddRate: result.max_drawdown_rate,
              isRecentThreeMonths: result.instrument.currency == 'USD',
              isFictional: result.data_source == 'fictional_demo',
            ),
            const SizedBox(height: 20),

            // MDD Period Details
            Text(
              result.data_source == 'fictional_demo'
                  ? '가상 하락 구간 (MDD 예시)'
                  : '주요 하락 구간 (MDD 상세)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _DrawdownRow(
                    label: '직전 최고점 (Peak)',
                    value: result.peak_date ?? '구간 내 없음',
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppColors.primary,
                  ),
                  const Divider(height: 18, color: AppColors.border),
                  _DrawdownRow(
                    label: '최대 하락점 (Trough)',
                    value: result.trough_date ?? '구간 내 없음',
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppColors.danger,
                  ),
                  const Divider(height: 18, color: AppColors.border),
                  _DrawdownRow(
                    label: '전고점 회복일 (Recovery)',
                    value: _recoveryLabel(result),
                    icon: _recoveryIcon(result),
                    iconColor: _recoveryColor(result),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Warnings if any
            if (result.warnings.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pendingBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.pending,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '주의: ${result.warnings.map(_warningLabel).join(' ')}',
                        style: const TextStyle(
                          color: AppColors.pending,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text(
                '데이터 기준과 한계',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              children: [
                if (result.data_source == 'fictional_demo')
                  const _DataLimitText(
                    text:
                        '실제 시세를 조회하거나 저장한 값이 아닙니다. 표시된 날짜·지표·종목은 모두 임의의 가상 예시입니다.',
                  )
                else ...[
                  _DataLimitText(text: '데이터 제공자: ${result.data_source}'),
                  if (result.instrument.currency == 'USD') ...[
                    if (result.data_source == 'twelve_data+ecb_reference_fx')
                      const _DataLimitText(
                        text: 'Twelve Data 일별 종가는 분할 조정 기준이며 배당은 포함하지 않습니다.',
                      ),
                    _DataLimitText(
                      text:
                          '미국 주가(USD) × ECB 기준 원/달러 환율로 원화 가격을 산출했습니다. '
                          '최근 환율 기준일: ${result.fx_rate_as_of ?? '확인 불가'}.',
                    ),
                    const _DataLimitText(
                      text:
                          'ECB 환율은 EUR 대비 USD·KRW의 일별 기준값으로 계산한 참고 환율입니다. '
                          '실제 환전 가격·수수료와 다릅니다.',
                    ),
                  ] else
                    const _DataLimitText(
                      text: '기간 수익률·변동성·MDD는 제공자가 조정한 일별 종가를 사용합니다.',
                    ),
                  const _DataLimitText(
                    text: '액면분할·병합 등 기업행사 반영 기준과 과거 데이터 정정은 제공자 정책에 의존합니다.',
                  ),
                ],
                const _DataLimitText(
                  text: '배당을 포함한 총수익률이나 미래 손실 확률을 의미하지 않습니다.',
                ),
              ],
            ),

            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.data_source == 'fictional_demo'
                    ? '모든 종목·시세·지표는 가상 예시입니다. 미래 결과를 예측하거나 투자 판단을 제시하지 않습니다.'
                    : '과거 데이터는 미래 결과를 보장하지 않습니다. 본 서비스는 투자 추천, 매수·매도 판단을 '
                          '제공하지 않으며, 가정된 위험 충격을 이해하기 위한 예방 목적의 분석입니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPercent(double? rate, {bool showSign = true}) {
    if (rate == null) return '계산 불가';
    final pct = rate * 100;
    final sign = (showSign && pct > 0) ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }

  static Color _returnColor(double? rate) {
    if (rate == null) return AppColors.textMuted;
    if (rate > 0) return AppColors.success;
    if (rate < 0) return AppColors.danger;
    return AppColors.text;
  }
}

class _DataLimitText extends StatelessWidget {
  const _DataLimitText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '• $text',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

String _recoveryLabel(MarketRiskResult result) {
  if (result.max_drawdown_rate == null) {
    return '계산 불가';
  }
  if (result.max_drawdown_rate! >= 0) {
    return '해당 없음 (하락 구간 없음)';
  }
  return result.recovery_date ?? '미회복 (기간 내 최고점 미달)';
}

IconData _recoveryIcon(MarketRiskResult result) {
  if (result.max_drawdown_rate == null) {
    return Icons.help_outline_rounded;
  }
  if (result.max_drawdown_rate! >= 0 || result.recovery_date != null) {
    return Icons.check_circle_outline;
  }
  return Icons.timelapse_rounded;
}

Color _recoveryColor(MarketRiskResult result) {
  if (result.max_drawdown_rate == null) {
    return AppColors.textMuted;
  }
  if (result.max_drawdown_rate! >= 0 || result.recovery_date != null) {
    return AppColors.success;
  }
  return AppColors.pending;
}

String _warningLabel(String warning) {
  return switch (warning) {
    'INSUFFICIENT_PRICE_DATA' => '관측치가 부족해 일부 지표를 계산하지 못했습니다.',
    'PARTIAL_PRICE_HISTORY' => '요청한 전체 기간보다 짧은 구간만 관측했습니다.',
    'FX_REFERENCE_RATE' => '원화 수치는 ECB 참고 환율 기준이며 실제 환전 손익과 다릅니다.',
    'PRICE_ADJUSTMENT_UNVERIFIED' => '미국 주가의 기업행사 조정 여부는 확인되지 않았습니다.',
    'MARKET_DATA_UNAVAILABLE' => '현재 시세 데이터를 불러올 수 없습니다.',
    _ => warning,
  };
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.description,
  });

  final String label;
  final String value;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MddHighlightTile extends StatelessWidget {
  const _MddHighlightTile({
    required this.mddRate,
    required this.isRecentThreeMonths,
    required this.isFictional,
  });

  final double? mddRate;
  final bool isRecentThreeMonths;
  final bool isFictional;

  @override
  Widget build(BuildContext context) {
    final formatted = mddRate != null
        ? '${(mddRate! * 100).toStringAsFixed(2)}%'
        : '계산 불가';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.trending_down_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  isFictional
                      ? '가상 구간 MDD'
                      : isRecentThreeMonths
                      ? '최근 3개월 MDD'
                      : '관측 구간 MDD',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatted,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isFictional
                ? '가상 가격 흐름에서 최고점 대비 하락을 가정한 설명용 수치입니다.'
                : '${isRecentThreeMonths ? '최근 3개월' : '조회 기간'} 중 누적 최고점 대비 최대 하락률입니다. 전체 과거의 최악을 뜻하지 않습니다.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DrawdownRow extends StatelessWidget {
  const _DrawdownRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
