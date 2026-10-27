import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/stress_test_models.dart';

class LeverageComparisonCard extends StatelessWidget {
  const LeverageComparisonCard({
    required this.withoutBorrowing,
    required this.withBorrowing,
    required this.profile,
    super.key,
  });

  final ScenarioResult withoutBorrowing;
  final ScenarioResult withBorrowing;
  final FinancialProfileInput profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '같은 ${withBorrowing.label} 가정',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '자기자본 ${_formatKrw(profile.equity_amount_krw)}과 소득·생활비·기존 대출은 동일합니다. '
              '차입이 없으면 자기자본만 투자하고, 차입이 있으면 자기자본에 차입금 ${_formatKrw(profile.borrowed_amount_krw)}을 더해 투자합니다. '
              '같은 수익률·환율 가정을 두 투자금에 각각 적용했습니다.',
            ),
            const SizedBox(height: 16),
            _CaseCard(
              title: '차입 없음',
              investment: profile.equity_amount_krw,
              borrowed: 0,
              result: withoutBorrowing,
            ),
            const SizedBox(height: 10),
            _CaseCard(
              title: '입력한 차입금 포함',
              investment: profile.planned_investment_krw,
              borrowed: profile.borrowed_amount_krw,
              result: withBorrowing,
            ),
            const SizedBox(height: 12),
            const Text(
              '투자금 규모가 다르므로 손실액을 직접 비교하되, 어느 쪽이 적합한지 판정하지 않습니다. 기존 대출은 두 경우 모두 유지합니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.title,
    required this.investment,
    required this.borrowed,
    required this.result,
  });

  final String title;
  final int investment;
  final int borrowed;
  final ScenarioResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: borrowed == 0 ? AppColors.primarySoft : AppColors.stressSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _Metric(label: '투자금', value: _formatKrw(investment)),
            _Metric(label: '투자용 차입 원금', value: _formatKrw(borrowed)),
            _Metric(
              label: '가정 손실',
              value: _formatKrw(result.investment_loss_krw),
            ),
            _Metric(
              label: '남은 순투자지분',
              value: _formatKrw(result.net_investment_equity_krw),
            ),
            _Metric(
              label: '차입금 추정 월 이자',
              value: _formatKrw(result.estimated_monthly_interest_krw),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
