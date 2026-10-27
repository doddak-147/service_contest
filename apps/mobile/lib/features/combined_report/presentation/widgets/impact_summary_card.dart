import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../stress_test/models/stress_test_models.dart';
import '../../models/combined_report_models.dart';

class ImpactSummaryCard extends StatelessWidget {
  const ImpactSummaryCard({
    required this.result,
    required this.profile,
    super.key,
  });

  final CombinedAnalysisResult result;
  final FinancialProfileInput profile;

  ScenarioResult? get _scenario {
    if (result.mdd_impact != null) return result.mdd_impact;
    for (final scenario in result.scenarios) {
      if (scenario.scenario_key == ScenarioKeys.down20) return scenario;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenario;
    final isHistorical = result.mdd_impact != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('한눈에 보는 손실 충격', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              isHistorical
                  ? '선택 종목의 관측 기간 중 최대 하락폭을 내 투자금에 적용한 가정'
                  : '종목 과거 위험을 적용하지 못해 주가 -20% 고정 가정으로 표시',
            ),
            if (scenario == null) ...[
              const SizedBox(height: 16),
              const Text('표시할 시나리오 결과가 없습니다.'),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                '적용한 원화 수익률 ${(scenario.assumed_return_rate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _formatKrw(scenario.investment_loss_krw),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.danger),
              ),
              const Text('가정한 투자금 손실'),
              const SizedBox(height: 18),
              _ValueBar(
                original: profile.planned_investment_krw,
                remaining: scenario.projected_investment_value_krw,
              ),
              const SizedBox(height: 14),
              Text(
                '투자금 ${_formatKrw(profile.planned_investment_krw)} → '
                '가정 적용 후 ${_formatKrw(scenario.projected_investment_value_krw)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '투자용 차입 원금 ${_formatKrw(profile.borrowed_amount_krw)}은 가격 충격 후에도 그대로라고 가정합니다. '
                '남은 순투자지분은 ${_formatKrw(scenario.net_investment_equity_krw)}입니다.',
              ),
              const SizedBox(height: 12),
              Text(
                '손실 / 자기자본: ${_formatPercent(scenario.loss_to_equity_ratio)}  ·  '
                '손실 / 월 고정지출: ${_formatMonths(scenario.loss_to_monthly_fixed_expenses)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (result.market_risk != null) ...[
                const SizedBox(height: 14),
                Text(
                  '시세: ${_sourceLabel(result.market_risk!.data_source)} · 기준일 ${result.market_risk!.data_as_of}'
                  '${result.market_risk!.fx_rate_as_of == null ? '' : ' · 환율 기준일 ${result.market_risk!.fx_rate_as_of}'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                '과거 관측값 또는 고정 가정을 적용한 계산이며 미래 손실 예측이 아닙니다.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueBar extends StatelessWidget {
  const _ValueBar({required this.original, required this.remaining});

  final int original;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final fraction = original <= 0
        ? 0.0
        : (remaining / original).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('가정 적용 후 남은 투자금 비율', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: AppColors.stressSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

String _formatKrw(int value) {
  final digits = value.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${value < 0 ? '-' : ''}$digits원';
}

String _formatPercent(double? value) =>
    value == null ? '계산 불가' : '${(value * 100).toStringAsFixed(1)}%';

String _formatMonths(double? value) =>
    value == null ? '계산 불가' : '약 ${value.toStringAsFixed(2)}개월';

String _sourceLabel(String source) => switch (source) {
  'twelve_data+ecb_reference_fx' => 'Twelve Data + ECB 참고환율',
  _ => source,
};
