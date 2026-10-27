import 'package:flutter/material.dart';

import '../input/krw_input_formatter.dart';
import '../theme/app_theme.dart';

class InvestmentTotalSummary extends StatelessWidget {
  const InvestmentTotalSummary({
    required this.equityController,
    required this.borrowedController,
    super.key,
  });

  final TextEditingController equityController;
  final TextEditingController borrowedController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([equityController, borrowedController]),
      builder: (context, _) {
        final equity = int.tryParse(equityController.text.replaceAll(',', ''));
        final borrowed = int.tryParse(
          borrowedController.text.replaceAll(',', ''),
        );
        final total = equity == null || borrowed == null
            ? null
            : equity + borrowed;
        final value = total == null
            ? '두 금액을 입력하면 자동 계산됩니다'
            : '${formatKrwInput('$total')}원';

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Semantics(
            label: '총 투자 예정금액, 자기자본과 차입금의 합, $value',
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '총 투자 예정금액\n자동 계산',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
