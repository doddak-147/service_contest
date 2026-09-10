import 'package:flutter/material.dart';

import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
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
              '가정한 하락률에 따라 차입투자 손실과 대출이자, 생활비 대비 충격을 '
              '확인할 수 있습니다.',
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
              child: const Text('Stress Test 시작하기'),
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
