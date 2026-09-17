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
                  _formatAssumedRate(result.assumed_return_rate),
                  style: TextStyle(
                    color: result.assumed_return_rate < 0
                        ? AppColors.danger
                        : AppColors.primary,
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
              label: '시나리오 적용 후 투자 가치',
              value: _formatKrw(result.projected_investment_value_krw),
            ),
            _ResultRow(
              label: '자기자본 대비 손실',
              value: _formatPercent(result.loss_to_equity_ratio),
            ),
            _ResultRow(
              label: '비상자금 대비 손실',
              value: _formatPercent(result.loss_to_emergency_fund_ratio),
            ),
            _ResultRow(
              label: '남은 자기자본',
              value: _formatKrw(result.net_investment_equity_krw),
            ),
            _ResultRow(
              label: '기존 대출 + 투자용 차입금',
              value: _formatKrw(result.reported_total_debt_krw),
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
            _ResultRow(
              label: '손실 회복 필요 상승률',
              value: _formatRecoveryRate(result),
              detail: '손실 후 남은 투자금에서 원금으로 돌아가기 위해 필요한 상승률',
            ),
            if (result.unavailable_reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '계산 불가 사유',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...result.unavailable_reasons.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${_reasonMessage(reason)}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: const Text(
                  '계산 근거 보기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                children: const [
                  _FormulaText(text: '예상 손실 = 투자 예정금액 × 하락률'),
                  _FormulaText(text: '남은 자기자본 = 시나리오 적용 후 투자 가치 − 투자용 차입금'),
                  _FormulaText(text: '회복 필요 상승률 = 손실액 ÷ 손실 후 남은 투자금'),
                  _FormulaText(text: '예상 이자는 입력한 차입금과 연이율 기준이며 상환 방식은 반영하지 않음'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '선택한 시나리오를 적용한 가정 결과이며 미래 가격 예측이나 투자 권유가 '
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

class _FormulaText extends StatelessWidget {
  const _FormulaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '• $text',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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

String _formatRecoveryRate(ScenarioResult result) {
  if (result.recovery_required_rate != null) {
    return _formatPercent(result.recovery_required_rate);
  }
  if (result.unavailable_reasons.contains('NO_FINITE_RECOVERY_RATE')) {
    return '유한한 상승률로 회복 불가';
  }
  return '계산 불가';
}

String _formatAssumedRate(double rate) {
  final percent = rate * 100;
  final fractionDigits = percent == percent.roundToDouble() ? 0 : 1;
  final prefix = percent > 0 ? '+' : '';
  return '$prefix${percent.toStringAsFixed(fractionDigits)}%';
}

String _reasonMessage(String reason) {
  return switch (reason) {
    'ZERO_EQUITY' => '자기자본이 0원이라 자기자본 대비 손실률을 계산할 수 없습니다.',
    'ZERO_EMERGENCY_FUND' => '비상자금이 0원이라 비상자금 대비 손실률을 계산할 수 없습니다.',
    'ZERO_FIXED_EXPENSES' => '월 고정지출이 0원이라 생활비 기준 손실 규모를 계산할 수 없습니다.',
    'NO_FINITE_RECOVERY_RATE' => '투자금을 전부 잃은 경우 유한한 상승률로 원금을 회복할 수 없습니다.',
    _ => '일부 지표를 계산할 수 없습니다.',
  };
}
