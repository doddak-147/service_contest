import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/risk_quiz_api.dart';
import '../models/risk_lessons.dart';

class RiskLearningScreen extends StatefulWidget {
  const RiskLearningScreen({this.apiClient, this.offlineSeed, super.key});
  final ApiClient? apiClient;
  final int? offlineSeed;
  @override
  State<RiskLearningScreen> createState() => _RiskLearningScreenState();
}

class _RiskLearningScreenState extends State<RiskLearningScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _feedbackKey = GlobalKey();
  late RiskQuizRound _round;
  int _index = 0;
  int? _selected;
  bool _revealed = false, _loading = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _round = offlineRiskQuiz(seed: widget.offlineSeed);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _replace(RiskQuizRound round, {String? notice}) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _round = round;
      _index = 0;
      _selected = null;
      _revealed = false;
      _notice = notice;
    });
  }

  void _checkAnswer() {
    setState(() => _revealed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedback = _feedbackKey.currentContext;
      if (mounted && feedback != null) {
        Scrollable.ensureVisible(
          feedback,
          duration: const Duration(milliseconds: 300),
          alignment: .1,
        );
      }
    });
  }

  Future<void> _newRound({bool ai = false}) async {
    if (_loading) return;
    if (!ai || widget.apiClient == null) {
      _replace(offlineRiskQuiz());
      return;
    }
    setState(() => _loading = true);
    try {
      final round = await RiskQuizApi(
        widget.apiClient!,
      ).generate(Random().nextInt(2147483647));
      if (!mounted) return;
      final reason = switch (round.fallback_reason) {
        'not_configured' => 'AI 연결이 설정되지 않아 가상 수치를 바꾼 자체 문제를 구성했습니다.',
        'provider_unavailable' => 'AI 응답을 받지 못해 자체 문제로 이어갑니다.',
        'safety_rejected' => 'AI 문구 검증을 통과하지 못해 자체 문제로 이어갑니다.',
        _ => null,
      };
      _replace(round, notice: reason);
    } catch (_) {
      if (mounted) {
        _replace(
          offlineRiskQuiz(),
          notice: '문제 생성 서버에 연결할 수 없어 오프라인 문제로 이어갑니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _round.questions[_index];
    final correct = _selected == lesson.correct_index;
    return Scaffold(
      appBar: AppBar(title: const Text('짧은 위험 이해 체험')),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _round.source == 'llm'
                  ? 'AI 상황 문구 · 가상 수치와 정답은 검증 계산'
                  : '완전 가상 사례 · 자체 문제 · 실제 시세 미사용',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.apiClient != null)
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _newRound(ai: true),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(_loading ? '새 문제를 구성하고 있습니다…' : 'AI로 새 5문제 만들기'),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(_notice!, semanticsLabel: _notice),
              ),
            const SizedBox(height: 16),
            Text(
              '${_index + 1}/5 · ${lesson.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (_index + 1) / 5),
            if (lesson.intro.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(lesson.intro),
              ),
            const SizedBox(height: 20),
            Text(lesson.prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final entry in lesson.options.asMap().entries)
              _option(lesson, entry.key, entry.value),
            FilledButton(
              onPressed: _loading || _selected == null || _revealed
                  ? null
                  : _checkAnswer,
              child: Text(_revealed ? '정답 확인 완료' : '정답 확인'),
            ),
            if (_revealed) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Card(
                  key: _feedbackKey,
                  color: correct
                      ? AppColors.successBackground
                      : AppColors.dangerBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              correct ? Icons.check_circle : Icons.cancel,
                              color: correct
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            Text(
                              correct ? '정답입니다!' : '오답입니다.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '정답: ${lesson.options[lesson.correct_index]}',
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
              ),
              const SizedBox(height: 12),
              if (_index == 4) ...[
                const Text('5문제 체험을 마쳤습니다. 정답과 계산 근거를 생활 속 개념으로 확인해 보세요.'),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _newRound(ai: widget.apiClient != null),
                  child: const Text('새 5문제 시작'),
                ),
              ] else
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                          setState(() {
                            _index++;
                            _selected = null;
                            _revealed = false;
                          });
                        },
                  child: const Text('다음 문제'),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              '금융 개념을 가상 사례로 확인합니다. 투자 실력 점수나 투자 가능 여부를 판정하지 않으며 선택 기록은 저장하지 않습니다.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(RiskLesson lesson, int index, String text) {
    final selected = _selected == index;
    final answer = _revealed && index == lesson.correct_index;
    final wrong = _revealed && selected && !answer;
    final color = answer
        ? AppColors.success
        : wrong
        ? AppColors.danger
        : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Card(
          color: answer
              ? AppColors.successBackground
              : wrong
              ? AppColors.dangerBackground
              : selected
              ? AppColors.primarySoft
              : AppColors.surface,
          child: ListTile(
            leading: Icon(
              answer
                  ? Icons.check_circle
                  : wrong
                  ? Icons.cancel
                  : selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: color,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (answer || wrong)
                  Text(
                    answer ? '정답' : '내 선택 · 오답',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            onTap: _loading || _revealed
                ? null
                : () => setState(() => _selected = index),
          ),
        ),
      ),
    );
  }
}
