import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/risk_lessons.dart';

class RiskLearningScreen extends StatefulWidget {
  const RiskLearningScreen({super.key});
  @override
  State<RiskLearningScreen> createState() => _RiskLearningScreenState();
}

class _RiskLearningScreenState extends State<RiskLearningScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  int _index = 0;
  int? _selected;
  bool _revealed = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = riskLessons[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('짧은 위험 이해 체험')),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '완전 가상 사례 · 실제 시세·AI·서버 요청 없음',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_index + 1}/${riskLessons.length} · ${lesson.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (_index + 1) / riskLessons.length),
            const SizedBox(height: 20),
            Text(lesson.prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final entry in lesson.options.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  selected: _selected == entry.key,
                  button: true,
                  child: Card(
                    color: _selected == entry.key
                        ? AppColors.primarySoft
                        : AppColors.surface,
                    child: ListTile(
                      leading: Icon(
                        _selected == entry.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(entry.value),
                      onTap: () => setState(() {
                        _selected = entry.key;
                        _revealed = false;
                      }),
                    ),
                  ),
                ),
              ),
            FilledButton(
              onPressed: _selected == null
                  ? null
                  : () => setState(() => _revealed = true),
              child: const Text('계산 근거 확인'),
            ),
            if (_revealed) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _selected == lesson.correctIndex
                            ? '계산과 같은 답입니다.'
                            : '선택한 답과 계산 결과를 비교해 보세요.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '계산 결과: ${lesson.options[lesson.correctIndex]}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(lesson.formula),
                      const SizedBox(height: 12),
                      Text(lesson.explanation),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  setState(() {
                    _index = (_index + 1) % riskLessons.length;
                    _selected = null;
                    _revealed = false;
                  });
                },
                child: Text(
                  _index == riskLessons.length - 1 ? '처음부터 다시 체험' : '다음 사례',
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '금융 개념을 가상 사례로 확인하는 체험입니다. 투자 실력 점수나 투자 가능 여부를 판정하지 않으며 선택 기록을 저장하지 않습니다.',
            ),
          ],
        ),
      ),
    );
  }
}
