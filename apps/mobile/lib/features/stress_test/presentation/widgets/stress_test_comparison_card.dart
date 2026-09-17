import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/stress_test_models.dart';

class StressTestComparisonCard extends StatelessWidget {
  const StressTestComparisonCard({required this.results, super.key});

  final List<ScenarioResult> results;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 620,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.3),
                3: FlexColumnWidth(1.2),
              },
              border: const TableBorder(
                horizontalInside: BorderSide(color: AppColors.border),
              ),
              children: [_headerRow(), ...results.map(_resultRow)],
            ),
          ),
        ),
      ),
    );
  }

  TableRow _headerRow() {
    return const TableRow(
      decoration: BoxDecoration(color: AppColors.background),
      children: [
        _TableCell(text: '시나리오', isHeader: true),
        _TableCell(text: '예상 손실', isHeader: true),
        _TableCell(text: '남은 자기자본', isHeader: true),
        _TableCell(text: '회복 필요 상승률', isHeader: true),
      ],
    );
  }

  TableRow _resultRow(ScenarioResult result) {
    return TableRow(
      children: [
        _TableCell(text: result.label),
        _TableCell(text: _formatKrw(result.investment_loss_krw)),
        _TableCell(text: _formatKrw(result.net_investment_equity_krw)),
        _TableCell(text: _formatPercent(result.recovery_required_rate)),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.text, this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AppColors.textMuted : AppColors.text,
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
        ),
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
    return '회복 불가';
  }
  return '${(value * 100).toStringAsFixed(1)}%';
}
