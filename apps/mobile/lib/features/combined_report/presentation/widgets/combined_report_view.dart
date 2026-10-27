import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../financial_health/presentation/widgets/financial_health_result_card.dart';
import '../../../market_risk/presentation/widgets/market_risk_card.dart';
import '../../../stress_test/presentation/widgets/stress_test_comparison_card.dart';
import '../../../stress_test/presentation/widgets/stress_test_result_card.dart';
import '../../../stress_test/models/stress_test_models.dart';
import '../../models/combined_report_models.dart';
import 'impact_summary_card.dart';

class CombinedReportView extends StatelessWidget {
  const CombinedReportView({
    required this.result,
    required this.financialProfile,
    required this.explanation,
    required this.explanationError,
    required this.isExplanationLoading,
    required this.onRetryExplanation,
    this.isExampleProfile = false,
    this.isOfflineDemo = false,
    super.key,
  });

  final CombinedAnalysisResult result;
  final FinancialProfileInput financialProfile;
  final bool isExampleProfile;
  final bool isOfflineDemo;
  final ExplanationResult? explanation;
  final String? explanationError;
  final bool isExplanationLoading;
  final VoidCallback onRetryExplanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '개인 × 종목 금융충격 Report',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          isOfflineDemo
              ? '가상 재무정보와 가상 종목 위험을 결합한 고정 예시입니다.'
              : '사용자의 재무정보와 선택 종목의 과거 위험을 같은 기준으로 결합한 결과입니다.',
        ),
        const SizedBox(height: 20),
        if (isOfflineDemo) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('완전 가상 데이터: 실제 시세·환율·AI 응답이나 서버 계산을 사용하지 않습니다.'),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (isExampleProfile) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '가상 재무 예시로 시작한 결과입니다. 재무 입력값을 수정했을 수 있으며, 종목의 과거 시세는 실제 데이터일 수 있습니다.',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ImpactSummaryCard(result: result, profile: financialProfile),
        const SizedBox(height: 20),
        const _SectionTitle(number: '1', title: '쉬운 결과 설명'),
        const SizedBox(height: 12),
        _ExplanationCard(
          explanation: explanation,
          errorMessage: explanationError,
          isLoading: isExplanationLoading,
          onRetry: onRetryExplanation,
          isOfflineDemo: isOfflineDemo,
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _WarningCard(warnings: result.warnings),
        ],
        const SizedBox(height: 20),
        Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ExpansionTile(
            title: const Text('계산 근거와 전체 시나리오 보기'),
            subtitle: const Text('재무·시세 지표, MDD 충격, 비교표'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle(number: '2', title: '개인 금융체력'),
              const SizedBox(height: 12),
              FinancialHealthResultCard(
                result: result.financial_health,
                isOfflineDemo: isOfflineDemo,
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                number: '3',
                title: isOfflineDemo ? '가상 종목 위험' : '종목 과거 위험',
              ),
              const SizedBox(height: 12),
              if (result.market_risk != null)
                MarketRiskCard(result: result.market_risk!)
              else
                const _UnavailableCard(
                  message: '주가 데이터를 가져오지 못해 종목 과거 위험과 MDD 결합 결과를 표시하지 않습니다.',
                ),
              const SizedBox(height: 28),
              _SectionTitle(
                number: '4',
                title: isOfflineDemo ? '가상 MDD 적용 충격' : '과거 MDD 적용 충격',
              ),
              const SizedBox(height: 12),
              if (result.mdd_impact != null)
                StressTestResultCard(
                  result: result.mdd_impact!,
                  isOfflineDemo: isOfflineDemo,
                )
              else
                const _UnavailableCard(
                  message:
                      '계산 가능한 과거 MDD가 없어 이 항목은 제외했습니다. 고정 시나리오는 계속 비교할 수 있습니다.',
                ),
              const SizedBox(height: 28),
              const _SectionTitle(number: '5', title: '전체 시나리오 비교'),
              const SizedBox(height: 12),
              if (result.market_risk?.instrument.currency == 'USD') ...[
                const Text(
                  '고정 시나리오는 환율 변동 0% 가정입니다. 과거 MDD는 당시 환율을 포함한 원화 기준입니다. 주가·환율 충격을 따로 비교하려면 종목 위험 화면의 Stress Test를 이용하세요.',
                ),
                const SizedBox(height: 12),
              ],
              StressTestComparisonCard(results: result.scenarios),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              result.disclaimer,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ReportMetadata(result: result),
      ],
    );
  }
}

class _ReportMetadata extends StatelessWidget {
  const _ReportMetadata({required this.result});

  final CombinedAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: const Text('계산 세부 정보'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('계산 버전 ${result.calculation_version}'),
          const SizedBox(height: 6),
          Text('계산 시각: ${result.calculated_at}'),
          const SizedBox(height: 4),
          Text(
            '요청 ID: ${result.request_id}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.dangerBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('확인할 사항', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${_warningMessage(warning)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.explanation,
    required this.errorMessage,
    required this.isLoading,
    required this.onRetry,
    this.isOfflineDemo = false,
  });

  final ExplanationResult? explanation;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRetry;
  final bool isOfflineDemo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOfflineDemo
                  ? '가상 예시 설명'
                  : isLoading
                  ? '결과 설명'
                  : explanation?.source == 'llm'
                  ? 'AI 쉬운 설명'
                  : '검증된 기본 설명',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Row(
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('계산 결과를 쉬운 말로 설명하고 있습니다...')),
                ],
              )
            else if (explanation != null) ...[
              if (explanation!.source == 'template' && !isOfflineDemo) ...[
                Text(switch (explanation!.fallback_reason) {
                  'not_configured' => '현재 서버에 AI 설명 설정이 없어 검증된 기본 설명을 표시합니다.',
                  'provider_unavailable' =>
                    'AI 서비스 응답을 받지 못해 검증된 기본 설명을 표시합니다.',
                  'safety_rejected' => 'AI 문장이 검증 기준을 통과하지 못해 기본 설명을 표시합니다.',
                  _ => '검증된 기본 설명을 표시합니다.',
                }, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 10),
              ],
              Text(explanation!.summary, style: const TextStyle(height: 1.55)),
              const SizedBox(height: 10),
              Text(
                explanation!.caution,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              Text(errorMessage ?? '결과 설명을 불러오지 못했습니다.'),
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('설명 다시 요청')),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary,
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.surface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

String _warningMessage(String warning) {
  return switch (warning) {
    'MARKET_DATA_UNAVAILABLE' => '주가 데이터 제공자와 통신하지 못해 시장 위험과 MDD 충격을 제외했습니다.',
    'INSTRUMENT_NOT_FOUND' => '선택한 종목을 찾지 못해 시장 위험과 MDD 충격을 제외했습니다.',
    'INSUFFICIENT_PRICE_DATA' => '관측 주가가 부족해 일부 시장 지표와 MDD 충격을 계산하지 못했습니다.',
    'PARTIAL_PRICE_HISTORY' => '요청 기간 중 일부 구간만 시세가 제공됩니다.',
    'FX_REFERENCE_RATE' => '미국 종목의 원화 지표는 ECB 참고 환율로 계산했으며 실제 환전 가격과 다릅니다.',
    'PRICE_ADJUSTMENT_UNVERIFIED' => '미국 주가의 기업행사 조정 여부는 확인되지 않았습니다.',
    'ZERO_ESSENTIAL_OUTFLOW' => '월 필수지출이 0원이라 비상자금 버팀 기간을 계산하지 못했습니다.',
    _ => '일부 결과를 계산할 수 없어 해당 값을 제외했습니다.',
  };
}
