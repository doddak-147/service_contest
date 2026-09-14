import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/financial_health_models.dart';

class FinancialHealthResultCard extends StatelessWidget {
  const FinancialHealthResultCard({required this.result, super.key});

  final FinancialHealthResult result;

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
            const Text(
              'FINANCIAL HEALTH 결과',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text('현재 입력 기준', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Divider(height: 1),
            _ResultRow(
              label: '월 잉여현금',
              value: _formatKrw(result.monthly_surplus_krw),
              detail: '월 소득 - 월 고정지출 - 기존 월 대출 상환액',
            ),
            _ResultRow(
              label: '비상자금 버팀 기간',
              value: _formatMonths(result.emergency_runway_months),
              detail: _runwayDetail(result),
            ),
            _ResultRow(
              label: '투자금 중 차입 비율',
              value: _formatPercent(result.leverage_ratio),
            ),
            _ResultRow(
              label: '투자용 차입 예상 월 이자',
              value: _formatKrw(result.estimated_monthly_interest_krw),
            ),
            _ResultRow(
              label: '기존 대출 + 투자용 차입금',
              value: _formatKrw(result.reported_total_debt_krw),
            ),
            const SizedBox(height: 16),
            const Text(
              '이 결과는 입력한 재무정보를 수치로 정리한 것이며 투자 가능 여부나 '
              '매수·매도 판단을 제시하지 않습니다. 금융 계산은 서버의 결정론적 '
              'Python 코드에서 수행됩니다.',
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
  const _ResultRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

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
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
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

String? _runwayDetail(FinancialHealthResult result) {
  if (result.unavailable_reasons.contains('ZERO_ESSENTIAL_OUTFLOW')) {
    return '월 고정지출과 기존 월 상환액의 합이 0원이라 계산하지 않았습니다.';
  }
  return '비상자금 ÷ (월 고정지출 + 기존 월 대출 상환액)';
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
