import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../combined_report/presentation/widgets/combined_report_view.dart';
import '../financial_health/presentation/widgets/financial_health_result_card.dart';
import '../market_risk/presentation/widgets/market_risk_card.dart';
import 'offline_demo_data.dart';

/// A fixed, fictional walkthrough. It has no API client and makes no requests.
class OfflineDemoScreen extends StatefulWidget {
  const OfflineDemoScreen({super.key});

  @override
  State<OfflineDemoScreen> createState() => _OfflineDemoScreenState();
}

class _OfflineDemoScreenState extends State<OfflineDemoScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오프라인 체험')),
      body: SafeArea(
        child: Column(
          children: [
            const _FictionalNotice(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_step + 1}/3 · ${const ['가상 재무', '가상 종목', '결합 결과'][_step]}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (_step == 0) ...[
                    const Text('예시 인물의 재무 상태를 살펴봅니다. 입력이나 서버 계산은 하지 않습니다.'),
                    const SizedBox(height: 14),
                    const _ExampleProfileCard(),
                    const SizedBox(height: 14),
                    const FinancialHealthResultCard(
                      result: OfflineDemoData.financialHealth,
                      isOfflineDemo: true,
                    ),
                  ] else if (_step == 1) ...[
                    const Text(
                      '실존하지 않는 가상기업 A의 수치를 사용합니다. 종목 검색·시세 조회는 하지 않습니다.',
                    ),
                    const SizedBox(height: 14),
                    const MarketRiskCard(result: OfflineDemoData.marketRisk),
                  ] else
                    const CombinedReportView(
                      result: OfflineDemoData.report,
                      financialProfile: OfflineDemoData.profile,
                      explanation: OfflineDemoData.explanation,
                      explanationError: null,
                      isExplanationLoading: false,
                      onRetryExplanation: _noOp,
                      isOfflineDemo: true,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    SizedBox(
                      width: 100,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('이전'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _step == 2
                          ? () => setState(() => _step = 0)
                          : () => setState(() => _step++),
                      child: Text(
                        _step == 0
                            ? '가상 종목 보기'
                            : _step == 1
                            ? '결합 결과 보기'
                            : '처음부터 다시 보기',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _noOp() {}

class _FictionalNotice extends StatelessWidget {
  const _FictionalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primarySoft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Text(
        '완전 가상 데이터 · 실제 시세/환율/AI 미사용 · 서버 요청 없음',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _ExampleProfileCard extends StatelessWidget {
  const _ExampleProfileCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('가상 재무 입력', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('월 소득 300만 원 · 월 고정지출 150만 원'),
            Text('비상자금 500만 원 · 기존 대출 1,000만 원'),
            Text('투자금 1,000만 원 = 자기자본 600만 원 + 차입 400만 원'),
            Text('차입 연이율 6% · 기존 월 상환액 40만 원'),
          ],
        ),
      ),
    );
  }
}
