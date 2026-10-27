import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../financial_health/presentation/financial_health_screen.dart';
import '../../market_risk/presentation/market_risk_screen.dart';
import '../../stress_test/presentation/stress_test_screen.dart';
import 'about_screen.dart';
import 'widgets/server_status_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const _HeroBanner(),
            const SizedBox(height: 16),
            _QuickStartCard(apiClient: apiClient),
            const SizedBox(height: 16),
            ServerStatusCard(apiClient: apiClient),
            const SizedBox(height: 24),
            const _SectionHeading(
              title: '바로 살펴보기',
              description: '필요한 분석을 따로 확인할 수도 있습니다.',
            ),
            const SizedBox(height: 14),
            _FeatureActionCard(
              eyebrow: 'STRESS TEST · 가정 시나리오',
              title: '차입투자 Stress Test 시작하기',
              description: '하락률에 따른 예상 손실과 대출이자 부담을 계산합니다.',
              icon: Icons.monitor_heart_outlined,
              color: AppColors.stress,
              backgroundColor: AppColors.stressSoft,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StressTestScreen(apiClient: apiClient),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _FeatureActionCard(
              eyebrow: '과거 데이터 · 위험 지표',
              title: '종목 과거 위험 분석하기',
              description: '과거 최대낙폭과 변동성을 객관적인 수치로 살펴봅니다.',
              icon: Icons.show_chart_rounded,
              color: AppColors.market,
              backgroundColor: AppColors.marketSoft,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarketRiskScreen(apiClient: apiClient),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                );
              },
              icon: const Icon(Icons.info_outline_rounded, size: 19),
              label: const Text('서비스 원칙 보기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard({required this.apiClient});

  final ApiClient apiClient;

  void _openFinancialHealth(BuildContext context, FinancialInputMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FinancialHealthScreen(apiClient: apiClient, inputMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 손실 충격 살펴보기', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const Text('① 재무상태 입력  →  ② 종목 선택  →  ③ 결합 결과'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  _openFinancialHealth(context, FinancialInputMode.example),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('가상 예시로 체험'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _openFinancialHealth(context, FinancialInputMode.personal),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('내 값으로 시작'),
            ),
            const SizedBox(height: 8),
            Text(
              '예시는 재무 입력만 가상입니다. 종목을 선택하면 실제 과거 시세가 사용될 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26073B46),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '금융위험 예방 서비스',
                style: TextStyle(
                  color: Color(0xFFD9F4F5),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            '투자 전,\n손실의 무게를 확인하세요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '얼마나 벌 수 있는지가 아니라, 지금의 내가 손실을 얼마나 감당할 수 있는지 계산합니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFD9E8EA),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PrincipleTag(label: '투자 추천 없음'),
              _PrincipleTag(label: '미래 예측 없음'),
              _PrincipleTag(label: '계산 근거 공개'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrincipleTag extends StatelessWidget {
  const _PrincipleTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        border: Border.all(color: const Color(0x3DFFFFFF)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _FeatureActionCard extends StatelessWidget {
  const _FeatureActionCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
