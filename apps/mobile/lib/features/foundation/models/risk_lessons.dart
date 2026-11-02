class RiskLesson {
  const RiskLesson({
    required this.title,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.formula,
    required this.explanation,
  });
  final String title, prompt, formula, explanation;
  final List<String> options;
  final int correctIndex;
}

const riskLessons = <RiskLesson>[
  RiskLesson(
    title: '하락과 회복은 같은 비율일까요?',
    prompt:
        '가상 투자금 100만 원이 50% 하락해 50만 원이 됐습니다. 원래 100만 원으로 돌아오려면 남은 금액에서 몇 % 올라야 할까요?',
    options: ['50% 상승', '100% 상승', '200% 상승'],
    correctIndex: 1,
    formula: '(100만 − 50만) ÷ 50만 = 100%',
    explanation:
        '하락률은 처음의 100만 원, 회복 상승률은 남은 50만 원이 기준입니다. 필요한 비율을 계산한 것이며 실제 회복 가능성이나 시점을 예측하지 않습니다.',
  ),
  RiskLesson(
    title: '달러 가격이 그대로라면?',
    prompt: '가상 달러 자산의 주가는 변하지 않고 원/달러 환율만 10% 하락했습니다. 원화로 환산한 가치는 어떻게 될까요?',
    options: ['10% 감소', '변화 없음', '10% 증가'],
    correctIndex: 0,
    formula: '(1 + 0%) × (1 − 10%) − 1 = −10%',
    explanation:
        '같은 달러 금액을 원화로 바꾼 값이 줄어드는 가정입니다. 환전 수수료와 세금은 제외했으며 실제 환율을 사용하지 않았습니다.',
  ),
  RiskLesson(
    title: '현금 수익 없이 이자를 낸다면?',
    prompt:
        '가상 차입금 1,000만 원, 고정 연이율 6%로 원금 상환 없이 이자만 납부합니다. 6개월 동안 낸 이자 합계는 얼마일까요?',
    options: ['5만 원', '60만 원', '30만 원'],
    correctIndex: 2,
    formula: '1,000만 × 6% ÷ 12 × 6 = 30만 원',
    explanation:
        '월 이자 5만 원은 일정하고 납부한 누적 이자가 늘어납니다. 금리·원금 변화, 수수료, 일할 계산은 제외한 단순 가정입니다.',
  ),
  RiskLesson(
    title: '평가손실과 현금은 어떻게 다를까요?',
    prompt:
        '비상자금은 현금 500만 원입니다. 보유한 가상 주식에 평가손실 200만 원이 생겼지만 매도·추가 납부·다른 수입과 지출은 없었습니다. 현금 비상자금은 얼마일까요?',
    options: ['300만 원', '500만 원', '700만 원'],
    correctIndex: 1,
    formula: '현금 500만 + 현금 유입 0 − 현금 지출 0 = 500만 원',
    explanation:
        '현금은 그대로지만 투자자산의 가치는 200만 원 줄었습니다. 손실이 없다는 뜻은 아닙니다. 리스크 렌즈는 평가손익과 생활 현금 흐름을 구분해 보여줍니다.',
  ),
];
