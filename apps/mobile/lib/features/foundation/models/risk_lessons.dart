// ignore_for_file: non_constant_identifier_names
import 'dart:math';

class RiskLesson {
  const RiskLesson({
    required this.title,
    required this.prompt,
    required this.options,
    required this.correct_index,
    required this.formula,
    required this.explanation,
    required this.question_id,
    required this.topic,
    this.intro = '',
  });
  final String title, prompt, formula, explanation, question_id, topic, intro;
  final List<String> options;
  final int correct_index;
  factory RiskLesson.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List).cast<String>();
    final correct = json['correct_index'] as int;
    if (options.length != 3 ||
        options.toSet().length != 3 ||
        correct < 0 ||
        correct > 2) {
      throw const FormatException('문제의 선택지 또는 정답 형식이 올바르지 않습니다.');
    }
    return RiskLesson(
      question_id: json['question_id'] as String,
      topic: json['topic'] as String,
      title: json['title'] as String,
      intro: json['intro'] as String,
      prompt: json['prompt'] as String,
      options: List.unmodifiable(options),
      correct_index: correct,
      formula: json['formula'] as String,
      explanation: json['explanation'] as String,
    );
  }
}

class RiskQuizRound {
  const RiskQuizRound({
    required this.source,
    required this.questions,
    this.fallback_reason,
  });
  final String source;
  final String? fallback_reason;
  final List<RiskLesson> questions;
  factory RiskQuizRound.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List)
        .map((q) => RiskLesson.fromJson(q as Map<String, dynamic>))
        .toList(growable: false);
    final source = json['source'] as String;
    if (!['llm', 'template'].contains(source) ||
        questions.length != 5 ||
        questions.map((q) => q.question_id).toSet().length != 5 ||
        questions.map((q) => q.topic).toSet().length != 5) {
      throw const FormatException('한 묶음은 서로 다른 주제의 다섯 문제여야 합니다.');
    }
    return RiskQuizRound(
      source: source,
      questions: List.unmodifiable(questions),
      fallback_reason: json['fallback_reason'] as String?,
    );
  }
}

RiskQuizRound offlineRiskQuiz({int? seed}) {
  final bank = List<RiskLesson>.of(riskLessons)..shuffle(Random(seed));
  return RiskQuizRound(
    source: 'offline',
    questions: List.unmodifiable(bank.take(5)),
  );
}

const riskLessons = <RiskLesson>[
  RiskLesson(
    question_id: 'offline-recovery',
    topic: 'recovery',
    title: '하락과 회복은 같은 비율일까요?',
    prompt:
        '가상 투자금 100만 원이 50% 하락해 50만 원이 됐습니다. 원래 100만 원으로 돌아오려면 남은 금액에서 몇 % 올라야 할까요?',
    options: ['50% 상승', '100% 상승', '200% 상승'],
    correct_index: 1,
    formula: '(100만 − 50만) ÷ 50만 = 100%',
    explanation:
        '하락률은 처음의 100만 원, 회복 상승률은 남은 50만 원이 기준입니다. 필요한 비율을 계산한 것이며 실제 회복 가능성이나 시점을 예측하지 않습니다.',
  ),
  RiskLesson(
    question_id: 'offline-fx',
    topic: 'fx',
    title: '달러 가격이 그대로라면?',
    prompt: '가상 달러 자산의 주가는 변하지 않고 원/달러 환율만 10% 하락했습니다. 원화로 환산한 가치는 어떻게 될까요?',
    options: ['10% 감소', '변화 없음', '10% 증가'],
    correct_index: 0,
    formula: '(1 + 0%) × (1 − 10%) − 1 = −10%',
    explanation:
        '같은 달러 금액을 원화로 바꾼 값이 줄어드는 가정입니다. 환전 수수료와 세금은 제외했으며 실제 환율을 사용하지 않았습니다.',
  ),
  RiskLesson(
    question_id: 'offline-interest',
    topic: 'interest',
    title: '현금 수익 없이 이자를 낸다면?',
    prompt:
        '가상 차입금 1,000만 원, 고정 연이율 6%로 원금 상환 없이 이자만 납부합니다. 6개월 동안 낸 이자 합계는 얼마일까요?',
    options: ['5만 원', '60만 원', '30만 원'],
    correct_index: 2,
    formula: '1,000만 × 6% ÷ 12 × 6 = 30만 원',
    explanation:
        '월 이자 5만 원은 일정하고 납부한 누적 이자가 늘어납니다. 금리·원금 변화, 수수료, 일할 계산은 제외한 단순 가정입니다.',
  ),
  RiskLesson(
    question_id: 'offline-valuation',
    topic: 'valuation',
    title: '평가손실과 현금은 어떻게 다를까요?',
    prompt:
        '비상자금은 현금 500만 원입니다. 보유한 가상 주식에 평가손실 200만 원이 생겼지만 매도·추가 납부·다른 수입과 지출은 없었습니다. 현금 비상자금은 얼마일까요?',
    options: ['300만 원', '500만 원', '700만 원'],
    correct_index: 1,
    formula: '현금 500만 + 현금 유입 0 − 현금 지출 0 = 500만 원',
    explanation:
        '현금은 그대로지만 투자자산의 가치는 200만 원 줄었습니다. 손실이 없다는 뜻은 아닙니다. 리스크 렌즈는 평가손익과 생활 현금 흐름을 구분해 보여줍니다.',
  ),
  RiskLesson(
    question_id: 'offline-compound',
    topic: 'compound_fx',
    title: '주가와 환율이 함께 변한다면?',
    prompt: '가상 달러 자산의 주가는 20%, 원/달러 환율은 10% 하락했습니다. 원화 환산 가치의 하락률은 얼마일까요?',
    options: ['30% 하락', '28% 하락', '20% 하락'],
    correct_index: 1,
    formula: '(1 − 20%) × (1 − 10%) − 1 = −28%',
    explanation: '주가와 환율 변화는 곱해서 결합합니다. 단순 합계와 다르며 수수료·세금은 제외한 가상 사례입니다.',
  ),
  RiskLesson(
    question_id: 'offline-cash-flow',
    topic: 'cash_flow',
    title: '이번 달 생활자금은 얼마나 남을까요?',
    prompt:
        '가상 월 소득 300만 원, 생활비 150만 원, 기존 대출 상환 40만 원, 투자용 이자 2만 원입니다. 다른 출입금이 없으면 남는 현금은 얼마일까요?',
    options: ['110만 원', '108만 원', '150만 원'],
    correct_index: 1,
    formula: '300만 − 150만 − 40만 − 2만 = 108만 원',
    explanation: '생활비에 대출 상환과 이자를 중복 포함하지 않습니다. 주식 평가손익은 실제 현금 지출과 분리합니다.',
  ),
  RiskLesson(
    question_id: 'offline-rate',
    topic: 'rate_shock',
    title: '금리가 오르면 월 이자는?',
    prompt: '가상 투자용 차입금 600만 원의 연금리가 6%에서 8%로 올랐습니다. 원금이 같으면 월 이자는 얼마 증가할까요?',
    options: ['1만 원', '3만 원', '4만 원'],
    correct_index: 0,
    formula: '600만 × 8% ÷ 12 − 600만 × 6% ÷ 12 = 1만 원',
    explanation: '투자용 차입금의 월 이자는 3만 원에서 4만 원으로 바뀝니다. 기존 대출·수수료·일할 계산은 제외합니다.',
  ),
  RiskLesson(
    question_id: 'offline-drawdown',
    topic: 'drawdown',
    title: '고점에서 얼마나 내려왔을까요?',
    prompt: '가상 관측 기간에 가격이 고점 120에서 이후 저점 84로 하락했습니다. 고점 대비 하락률은 얼마일까요?',
    options: ['36% 하락', '20% 하락', '30% 하락'],
    correct_index: 2,
    formula: '(84 ÷ 120 − 1) × 100 = −30%',
    explanation: '가격 차이 36을 고점 120으로 나눕니다. 이 관측 구간의 낙폭이며 미래의 최악 상황을 예측하지 않습니다.',
  ),
];
