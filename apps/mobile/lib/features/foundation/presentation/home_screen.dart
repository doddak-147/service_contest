import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
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
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Text(
              '금융위험 예방 서비스',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '투자 전, 손실의 무게를 확인하세요.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '가정한 하락률에 따라 차입투자 손실과 대출이자, 생활비 대비 충격을 확인하고, '
              '종목의 역사적 최대 하락폭(MDD)과 변동성을 미리 조회할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ServerStatusCard(apiClient: apiClient),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StressTestScreen(apiClient: apiClient),
                  ),
                );
              },
              child: const Text('차입투자 Stress Test 시작하기'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarketRiskScreen(apiClient: apiClient),
                  ),
                );
              },
              child: const Text(
                '종목 과거 위험 분석하기',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                );
              },
              child: const Text('서비스 원칙 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
