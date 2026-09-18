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
            ServerStatusCard(apiClient: apiClient),
            const SizedBox(height: 28),
            const _SectionHeading(
              title: '분석 시작',
              description: '궁금한 금융 충격부터 차례로 확인해 보세요.',
            ),
            const SizedBox(height: 14),
            _FeatureActionCard(
              eyebrow: 'STEP 1 · 내 재무상태',
              title: '개인 금융체력 분석하기',
              description: '월 잉여자금과 비상자금으로 손실 대응력을 확인합니다.',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FinancialHealthScreen(apiClient: apiClient),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
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
