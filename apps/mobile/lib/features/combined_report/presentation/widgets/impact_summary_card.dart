import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../stress_test/models/stress_test_models.dart';
import '../../models/combined_report_models.dart';
import 'capital_structure_chart.dart';

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
              result.market_risk?.data_source == 'fictional_demo'
                  ? '가상기업 A의 임의 하락률을 가상 투자금에 적용한 설명용 예시입니다. 실제 관측 결과가 아닙니다.'
                  : isHistorical
                  ? '선택 종목의 ${result.market_risk?.instrument.currency == 'USD' ? '최근 3개월 ' : ''}관측 구간(${result.market_risk?.period_start} ~ ${result.market_risk?.period_end}) 최대 하락폭을 내 투자금에 적용한 가정입니다. 전체 과거의 최악을 뜻하지 않습니다.'
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
              CapitalStructureChart(profile: profile, scenario: scenario),
              const SizedBox(height: 12),
              Text(
                '손실 / 자기자본: ${_formatPercent(scenario.loss_to_equity_ratio)}  ·  '
                '손실 / 월 고정지출: ${_formatMonths(scenario.loss_to_monthly_fixed_expenses)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (result.market_risk != null) ...[
                const SizedBox(height: 14),
                Text(
                  '${result.market_risk!.data_source == 'fictional_demo' ? '자료' : '시세'}: ${_sourceLabel(result.market_risk!.data_source)} · ${result.market_risk!.data_source == 'fictional_demo' ? '가상 날짜' : '기준일'} ${result.market_risk!.data_as_of}'
                  '${result.market_risk!.fx_rate_as_of == null ? '' : ' · 환율 기준일 ${result.market_risk!.fx_rate_as_of}'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                result.market_risk?.data_source == 'fictional_demo'
                    ? '모두 고정 가상 예시값이며 미래 손실 예측이 아닙니다.'
                    : '과거 관측값 또는 고정 가정을 적용한 계산이며 미래 손실 예측이 아닙니다.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
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
  'fictional_demo' => '가상 예시 데이터',
  _ => source,
};
