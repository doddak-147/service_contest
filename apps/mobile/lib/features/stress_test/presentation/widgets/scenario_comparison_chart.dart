import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../models/stress_test_models.dart';

/// Compares amounts already returned by the calculation API; no new data is fetched.
class ScenarioComparisonChart extends StatelessWidget {
  const ScenarioComparisonChart({required this.results, super.key});

  final List<ScenarioResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final maxAmount = results.fold<int>(1, (current, result) {
      return math.max(
        current,
        math.max(
          result.investment_loss_krw,
          math.max(0, result.net_investment_equity_krw),
        ),
      );
    });

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('시나리오별 손실 비교', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              '손실과 남은 순투자지분을 금액으로 비교합니다. 막대 길이는 아래 결과 중 최대 금액을 기준으로 합니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Legend(color: AppColors.danger, label: '가정한 손실'),
                _Legend(color: AppColors.primary, label: '남은 순투자지분'),
              ],
            ),
            const SizedBox(height: 8),
            ...results.map(
              (result) => _ScenarioBars(result: result, maxAmount: maxAmount),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioBars extends StatelessWidget {
  const _ScenarioBars({required this.result, required this.maxAmount});

  final ScenarioResult result;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final equity = result.net_investment_equity_krw;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          _AmountBar(
            label: '손실',
            amount: result.investment_loss_krw,
            fraction: result.investment_loss_krw / maxAmount,
            color: AppColors.danger,
            backgroundColor: AppColors.dangerBackground,
          ),
          const SizedBox(height: 5),
          _AmountBar(
            label: '순투자지분',
            amount: equity,
            fraction: math.max(0, equity) / maxAmount,
            color: AppColors.primary,
            backgroundColor: AppColors.primarySoft,
          ),
        ],
      ),
    );
  }
}

class _AmountBar extends StatelessWidget {
  const _AmountBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final int amount;
  final double fraction;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 10,
                color: color,
                backgroundColor: backgroundColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            _formatKrw(amount),
            textAlign: TextAlign.end,
            maxLines: 1,
            style: TextStyle(
              color: amount < 0 ? AppColors.danger : AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
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
