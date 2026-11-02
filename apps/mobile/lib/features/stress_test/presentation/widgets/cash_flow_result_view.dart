import 'package:flutter/material.dart';
import '../../../../shared/input/krw_input_formatter.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/comparison_line_chart.dart';
import '../../models/cash_flow_models.dart';

String cashMoney(int value) => '${formatKrwInput('$value')}원';

class CashFlowResultView extends StatefulWidget {
  const CashFlowResultView({
    required this.result,
    this.isOfflineDemo = false,
    super.key,
  });
  final CashFlowResult result;
  final bool isOfflineDemo;
  @override
  State<CashFlowResultView> createState() => _CashFlowResultViewState();
}

class _CashFlowResultViewState extends State<CashFlowResultView> {
  int _graph = 0;
  bool _showBaseline = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final before = r.baseline.monthly_points.first;
    final after = r.shocked.monthly_points.first;
    final shortfall = r.shocked.first_shortfall_month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '생활 충격 · ${r.months}개월 결과',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('시작 현금 ${cashMoney(r.initial_cash_krw)} · 현재 조건과 충격 조건을 비교합니다.'),
        if (widget.isOfflineDemo) const Text('완전 가상 고정 사례 · 실제 시세·AI·서버 요청 없음'),
        const SizedBox(height: 12),
        _comparison(
          '첫 달 투자용 이자',
          before.investment_interest_krw,
          after.investment_interest_krw,
        ),
        _comparison(
          '첫 달 지출·상환 후 남는 돈',
          before.monthly_net_cash_krw,
          after.monthly_net_cash_krw,
        ),
        _comparison(
          '${r.months}개월 말 현금 여력',
          r.baseline.ending_cash_balance_krw,
          r.shocked.ending_cash_balance_krw,
        ),
        _comparison(
          '${r.months}개월 누적 투자용 이자',
          r.baseline.total_interest_krw,
          r.shocked.total_interest_krw,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              shortfall == null
                  ? '이 가정과 기간에는 누적 현금 여력이 음수가 되는 달이 없습니다. 투자 적합성 판정은 아닙니다.'
                  : '$shortfall개월차부터 현금이 부족해지는 가정입니다. 음수는 자동 대출이 아니라 필요한 추가 자금입니다.',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final entry in const [
              '현금 여력',
              '월 수입·지출',
              '누적 이자',
            ].asMap().entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _graph == entry.key,
                onSelected: (_) => setState(() => _graph = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _chart(r),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '투자자산 · 별도의 즉시 평가 충격',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '가정 적용 자산 ${cashMoney(r.investment_effect.projected_investment_value_krw)}',
                ),
                Text(
                  '평가손익 ${cashMoney(r.investment_effect.investment_pnl_krw)}',
                ),
                const Text(
                  '이 평가손익은 위 현금 그래프에 더하거나 빼지 않습니다. 이후 가격과 매도·배당 수입은 가정하지 않습니다.',
                ),
              ],
            ),
          ),
        ),
        ExpansionTile(
          title: const Text('월별 수입·이자·상환 내역'),
          childrenPadding: const EdgeInsets.all(8),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('현재 조건'),
                  selected: _showBaseline,
                  onSelected: (_) => setState(() => _showBaseline = true),
                ),
                ChoiceChip(
                  label: const Text('충격 조건'),
                  selected: !_showBaseline,
                  onSelected: (_) => setState(() => _showBaseline = false),
                ),
              ],
            ),
            ...(_showBaseline ? r.baseline : r.shocked).monthly_points.map(
              (p) => ExpansionTile(
                title: Text(
                  '${p.month}개월차 · 현금 ${cashMoney(p.cash_balance_krw)}',
                ),
                subtitle: Text('월 수지 ${cashMoney(p.monthly_net_cash_krw)}'),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  _detail('월 소득', p.income_krw),
                  _detail('생활비·고정지출', p.fixed_expenses_krw),
                  _detail('기존 대출 상환', p.existing_debt_payment_krw),
                  _detail('투자용 이자', p.investment_interest_krw),
                  _detail('투자용 원금상환', p.investment_principal_payment_krw),
                  _detail('남은 투자용 원금', p.investment_loan_balance_krw),
                  _detail('누적 투자용 이자', p.cumulative_interest_krw),
                  if (p.cash_shortfall_krw > 0)
                    _detail('현금 부족분', p.cash_shortfall_krw),
                ],
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('계산 가정과 한계'),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            for (final line in r.assumptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $line'),
              ),
            Text('계산 버전: ${r.calculation_version}'),
          ],
        ),
      ],
    );
  }

  Widget _comparison(String label, int before, int after) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('현재 조건\n${cashMoney(before)}')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 18),
              ),
              Expanded(
                child: Text(
                  '충격 조건\n${cashMoney(after)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _detail(String label, int value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(cashMoney(value), textAlign: TextAlign.right)),
      ],
    ),
  );

  Widget _chart(CashFlowResult r) {
    final points = r.shocked.monthly_points;
    final labels = [
      if (_graph != 1) '시작',
      ...points.map((p) => '${p.month}개월'),
    ];
    final List<LineSeries> series;
    if (_graph == 1) {
      series = [
        LineSeries(
          '월 소득',
          AppColors.primary,
          points.map((p) => p.income_krw / 10000).toList(),
        ),
        LineSeries(
          '생활비·고정지출',
          AppColors.danger,
          points.map((p) => p.fixed_expenses_krw / 10000).toList(),
        ),
        LineSeries(
          '상환·이자 합계',
          Colors.deepPurple,
          points
              .map(
                (p) =>
                    (p.existing_debt_payment_krw +
                        p.investment_interest_krw +
                        p.investment_principal_payment_krw) /
                    10000,
              )
              .toList(),
        ),
      ];
    } else {
      List<double?> values(CashFlowPathResult p) => _graph == 0
          ? [
              r.initial_cash_krw / 10000,
              ...p.monthly_points.map((p) => p.cash_balance_krw / 10000),
            ]
          : [
              0,
              ...p.monthly_points.map((p) => p.cumulative_interest_krw / 10000),
            ];
      series = [
        LineSeries('현재 조건', AppColors.primary, values(r.baseline)),
        LineSeries('충격 조건', AppColors.danger, values(r.shocked)),
      ];
    }
    return ComparisonLineChart(
      title: const ['현금 여력의 변화', '충격 조건의 월 수입·지출', '기간별 누적 투자용 이자'][_graph],
      labels: labels,
      series: series,
      unit: '만 원',
    );
  }
}
