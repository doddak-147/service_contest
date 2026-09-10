import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _principles = [
    '종목이나 매수·매도 시점을 추천하지 않습니다.',
    '미래 주가를 예측하거나 투자 가능 여부를 판단하지 않습니다.',
    '금융 계산은 검증 가능한 Python 코드로 수행합니다.',
    '과거 데이터의 출처와 기준일, 계산 근거를 함께 제공합니다.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서비스 안내')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '서비스가 지키는 원칙',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            '투자 전에 가정된 손실이 개인의 재무상태에 미칠 충격을 이해하도록 '
            '돕는 교육 목적의 서비스입니다.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (final (index, principle) in _principles.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(principle)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
