import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../stress_test/models/stress_test_models.dart';

/// Visualizes existing result amounts; the server remains the source of calculations.
class CapitalStructureChart extends StatelessWidget {
  const CapitalStructureChart({
    required this.profile,
    required this.scenario,
    super.key,
  });

  final FinancialProfileInput profile;
  final ScenarioResult scenario;

  @override
  Widget build(BuildContext context) {
    final initialValue = math.max(0, profile.planned_investment_krw);
    final afterValue = math.max(0, scenario.projected_investment_value_krw);
    final debt = math.max(0, profile.borrowed_amount_krw);
    final scale = math.max(
      1,
      math.max(initialValue, math.max(afterValue, debt)),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('손실 전후 자금 구조', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text(
              '두 막대는 같은 금액 눈금입니다. 세로선은 충격 후에도 그대로 남는 투자용 차입 원금입니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                _Legend(color: AppColors.primary, label: '투자 가치'),
                _Legend(color: AppColors.market, label: '차입 원금 기준선'),
                _Legend(color: Color(0x3DA9342A), label: '가정 손실'),
              ],
            ),
            const SizedBox(height: 16),
            _StructureRow(
              title: '충격 전 투자 가치',
              value: initialValue,
              detail:
                  '자기자본 ${_formatKrw(profile.equity_amount_krw)} + 차입 원금 ${_formatKrw(debt)}',
              principal: initialValue,
              debt: debt,
              scale: scale,
            ),
            const SizedBox(height: 16),
            _StructureRow(
              title: '가정 적용 후 투자 가치',
              value: afterValue,
              detail:
                  '남은 순투자지분 ${_formatKrw(scenario.net_investment_equity_krw)} · 차입 원금 ${_formatKrw(debt)} 유지',
              principal: initialValue,
              debt: debt,
              scale: scale,
              showLoss: true,
              isNegativeEquity: scenario.net_investment_equity_krw < 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _StructureRow extends StatelessWidget {
  const _StructureRow({
    required this.title,
    required this.value,
    required this.detail,
    required this.principal,
    required this.debt,
    required this.scale,
    this.showLoss = false,
    this.isNegativeEquity = false,
  });

  final String title;
  final int value;
  final String detail;
  final int principal;
  final int debt;
  final int scale;
  final bool showLoss;
  final bool isNegativeEquity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatKrw(value),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ExcludeSemantics(
          child: SizedBox(
            height: 20,
            child: CustomPaint(
              painter: _StructureBarPainter(
                value: value,
                principal: principal,
                debt: debt,
                scale: scale,
                showLoss: showLoss,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: TextStyle(
            color: isNegativeEquity ? AppColors.danger : AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        if (isNegativeEquity) ...[
          const SizedBox(height: 3),
          const Text(
            '투자 가치가 차입 원금보다 작아 순투자지분이 음수입니다.',
            style: TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _StructureBarPainter extends CustomPainter {
  const _StructureBarPainter({
    required this.value,
    required this.principal,
    required this.debt,
    required this.scale,
    required this.showLoss,
  });

  final int value;
  final int principal;
  final int debt;
  final int scale;
  final bool showLoss;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(track, Paint()..color = AppColors.surface);
    canvas.save();
    canvas.clipRRect(track);

    double widthFor(int amount) =>
        size.width * (amount / scale).clamp(0.0, 1.0);

    if (showLoss && principal > value) {
      canvas.drawRect(
        Rect.fromLTRB(widthFor(value), 0, widthFor(principal), size.height),
        Paint()..color = AppColors.danger.withValues(alpha: 0.24),
      );
    }

    if (value > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, widthFor(value), size.height),
        Paint()..color = AppColors.primary,
      );
    }
    canvas.restore();

    if (debt > 0) {
      final markerX = widthFor(debt).clamp(1.0, size.width - 1);
      canvas.drawLine(
        Offset(markerX, 0),
        Offset(markerX, size.height),
        Paint()
          ..color = AppColors.market
          ..strokeWidth = 2,
      );
    }
    canvas.drawRRect(
      track,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_StructureBarPainter oldDelegate) =>
      value != oldDelegate.value ||
      principal != oldDelegate.principal ||
      debt != oldDelegate.debt ||
      scale != oldDelegate.scale ||
      showLoss != oldDelegate.showLoss;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
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
