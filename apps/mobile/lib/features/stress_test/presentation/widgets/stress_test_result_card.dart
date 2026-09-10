import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/stress_test_models.dart';

class StressTestResultCard extends StatelessWidget {
  const StressTestResultCard({required this.result, super.key});

  final ScenarioResult result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STRESS TEST 결과',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.label} 가정',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(result.assumed_return_rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            _ResultRow(
              emphasize: true,
              label: '예상 투자손실',
              value: _formatKrw(result.investment_loss_krw),
            ),
            _ResultRow(
              label: '자기자본 대비 손실',
              value: _formatPercent(result.loss_to_equity_ratio),
            ),
            _ResultRow(
              label: '남은 자기자본',
              value: _formatKrw(result.net_investment_equity_krw),
            ),
            _ResultRow(
              detail: '월 ${_formatKrw(result.estimated_monthly_interest_krw)}',
              label: '예상 대출이자',
              value: '연 ${_formatKrw(result.estimated_annual_interest_krw)}',
            ),
            _ResultRow(
              label: '생활비 기준 손실 규모',
              value: _formatMonths(result.loss_to_monthly_fixed_expenses),
            ),
            const SizedBox(height: 16),
            const Text(
              '선택한 하락률을 적용한 가정 결과이며 미래 가격 예측이나 투자 권유가 '
              '아닙니다. 계산은 서버의 결정론적 Python 코드로 수행됩니다.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.detail,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: emphasize ? AppColors.danger : AppColors.text,
              fontSize: emphasize ? 26 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatKrw(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return '$sign${buffer.toString()}원';
}

String _formatPercent(double? value) {
  if (value == null) {
    return '계산 불가';
  }
  return '${(value * 100).toStringAsFixed(1)}%';
}

String _formatMonths(double? value) {
  if (value == null) {
    return '계산 불가';
  }
  return '약 ${value.toStringAsFixed(2)}개월';
}
