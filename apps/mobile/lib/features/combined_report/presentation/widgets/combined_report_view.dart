import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../financial_health/presentation/widgets/financial_health_result_card.dart';
import '../../../market_risk/presentation/widgets/market_risk_card.dart';
import '../../../stress_test/presentation/widgets/stress_test_comparison_card.dart';
import '../../../stress_test/presentation/widgets/stress_test_result_card.dart';
import '../../models/combined_report_models.dart';

class CombinedReportView extends StatelessWidget {
  const CombinedReportView({
    required this.result,
    required this.explanation,
    required this.explanationError,
    required this.isExplanationLoading,
    required this.onRetryExplanation,
    super.key,
  });

  final CombinedAnalysisResult result;
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
        const Text('사용자의 재무정보와 선택 종목의 과거 위험을 같은 기준으로 결합한 결과입니다.'),
        const SizedBox(height: 20),
        _ReportMetadata(result: result),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _WarningCard(warnings: result.warnings),
        ],
        const SizedBox(height: 28),
        const _SectionTitle(number: '1', title: '개인 금융체력'),
        const SizedBox(height: 12),
        FinancialHealthResultCard(result: result.financial_health),
        const SizedBox(height: 28),
        const _SectionTitle(number: '2', title: '종목 과거 위험'),
        const SizedBox(height: 12),
        if (result.market_risk != null)
          MarketRiskCard(result: result.market_risk!)
        else
          const _UnavailableCard(
            message: '주가 데이터를 가져오지 못해 종목 과거 위험과 MDD 결합 결과를 표시하지 않습니다.',
          ),
        const SizedBox(height: 28),
        const _SectionTitle(number: '3', title: '과거 MDD 적용 충격'),
        const SizedBox(height: 12),
        if (result.mdd_impact != null)
          StressTestResultCard(result: result.mdd_impact!)
        else
          const _UnavailableCard(
            message: '계산 가능한 과거 MDD가 없어 이 항목은 제외했습니다. 고정 시나리오는 계속 비교할 수 있습니다.',
          ),
        const SizedBox(height: 28),
        const _SectionTitle(number: '4', title: '전체 시나리오 비교'),
        const SizedBox(height: 12),
        StressTestComparisonCard(results: result.scenarios),
        const SizedBox(height: 28),
        const _SectionTitle(number: '5', title: '쉬운 결과 설명'),
        const SizedBox(height: 12),
        _ExplanationCard(
          explanation: explanation,
          errorMessage: explanationError,
          isLoading: isExplanationLoading,
          onRetry: onRetryExplanation,
        ),
        const SizedBox(height: 24),
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
      ],
    );
  }
}

class _ReportMetadata extends StatelessWidget {
  const _ReportMetadata({required this.result});

  final CombinedAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계산 버전 ${result.calculation_version}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('계산 시각: ${result.calculated_at}'),
            const SizedBox(height: 4),
            Text(
              '요청 ID: ${result.request_id}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
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
  });

  final ExplanationResult? explanation;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRetry;

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
              isLoading
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
    'ZERO_ESSENTIAL_OUTFLOW' => '월 필수지출이 0원이라 비상자금 버팀 기간을 계산하지 못했습니다.',
    _ => '일부 결과를 계산할 수 없어 해당 값을 제외했습니다.',
  };
}
