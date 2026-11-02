"""Fictional questions. All facts, options and answers are calculated here."""

import random
from decimal import ROUND_HALF_UP, Decimal

from pydantic import BaseModel, ConfigDict, Field


class QuizRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    seed: int | None = Field(default=None, ge=0, le=2147483647)


class QuizQuestion(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    question_id: str
    topic: str
    title: str
    intro: str = ""
    prompt: str
    options: list[str]
    correct_index: int
    formula: str
    explanation: str


class QuizResult(BaseModel):
    source: str
    fallback_reason: str | None = None
    questions: list[QuizQuestion]


TOPICS = {
    "recovery": "하락과 회복의 기준 금액",
    "fx": "달러 가격이 같을 때 환율의 영향",
    "compound_fx": "주가와 환율의 복합 충격",
    "interest": "일정한 월 이자와 누적 이자",
    "cash_flow": "수입에서 지출과 상환을 뺀 현금",
    "valuation": "평가손실과 실제 현금의 구분",
    "rate_shock": "금리 상승에 따른 월 이자 차이",
    "drawdown": "관측 고점 대비 하락률",
}


def _money(value: int | Decimal) -> str:
    return f"{int(value):,}원"


def _percent(value: int | Decimal) -> str:
    return (
        format(Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP), "f")
        .rstrip("0")
        .rstrip(".")
    )


def _round(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def build_quiz(seed: int) -> list[QuizQuestion]:
    rng = random.Random(seed)
    questions = []

    def add(
        topic: str,
        prompt: str,
        correct: str,
        wrong: list[str],
        formula: str,
        explanation: str,
    ) -> None:
        options = list(dict.fromkeys([correct, *wrong]))
        if len(options) != 3:
            raise ValueError("Question options must be distinct")
        rng.shuffle(options)
        questions.append(
            QuizQuestion(
                question_id=f"{topic}-{seed}",
                topic=topic,
                title=TOPICS[topic],
                prompt=prompt,
                options=options,
                correct_index=options.index(correct),
                formula=formula,
                explanation=explanation,
            )
        )

    drop = rng.choice([0, 20, 25, 50, 75, 100])
    recovery = Decimal(drop) / (100 - drop) * 100 if drop < 100 else None
    add(
        "recovery",
        f"가상 자산이 {drop}% 하락했습니다. "
        "남은 자산에서 원래 금액으로 돌아가려면 몇 % 상승해야 할까요? "
        "상승률은 소수 둘째 자리까지 반올림합니다.",
        f"{_percent(recovery)}% 상승" if recovery is not None else "유한한 회복률 없음",
        (
            [f"{drop}% 상승", f"{_percent(recovery * 2)}% 상승"]
            if drop not in (0, 100)
            else ["20% 상승", "200% 상승"]
        ),
        f"{drop} ÷ (100 − {drop}) × 100 = {_percent(recovery)}%"
        if recovery is not None
        else "남은 자산이 0이므로 유한한 상승률로 원금에 도달할 수 없습니다.",
        "하락률과 회복 상승률의 기준 금액이 다릅니다. "
        "수수료·세금은 제외했으며 실제 회복 시점을 예측하지 않습니다.",
    )

    fx = rng.choice([-10, -5, 5, 10])
    direction = "하락" if fx < 0 else "상승"
    add(
        "fx",
        "가상 달러 자산의 주가는 그대로이고 "
        f"원/달러 환율만 {abs(fx)}% {direction}했습니다. "
        "원화 환산 가치는 어떻게 변할까요?",
        f"{abs(fx)}% {'감소' if fx < 0 else '증가'}",
        ["변화 없음", f"{abs(fx)}% {'증가' if fx < 0 else '감소'}"],
        f"(1 + 0%) × (1 + ({fx}%)) − 1 = {fx}%",
        "같은 달러 금액도 원화로 환산한 값은 환율에 따라 달라집니다. "
        "실제 환율·환전 수수료·세금은 사용하지 않습니다.",
    )

    price, fx = rng.choice([-10, -20, -30]), rng.choice([-10, 10])
    combined = (1 + Decimal(price) / 100) * (1 + Decimal(fx) / 100) * 100 - 100
    add(
        "compound_fx",
        f"가상 달러 자산의 주가 변화율은 {price}%, "
        f"원/달러 환율 변화율은 {fx}%입니다. "
        "원화 가치의 변화율은 얼마일까요?",
        f"{_percent(combined)}%",
        [f"{price + fx}%", f"{price}%"],
        f"(1 + ({price}%)) × (1 + ({fx}%)) − 1 = {_percent(combined)}%",
        "두 변화율은 단순히 더하지 않고 곱합니다. "
        "배당·수수료·세금을 제외한 가상 계산이며 미래 가격 예측이 아닙니다.",
    )

    principal, rate, months = (
        rng.choice([4000000, 6000000, 10000000]),
        rng.choice([3, 6, 9]),
        rng.choice([3, 6, 12]),
    )
    monthly = _round(Decimal(principal) * rate / 100 / 12)
    total = monthly * months
    add(
        "interest",
        f"가상 차입금 {_money(principal)}, 고정 연이율 {rate}%입니다. "
        f"원금 상환 없이 매달 이자만 낼 때 {months}개월간 낸 이자의 합계는 얼마일까요?",
        _money(total),
        [_money(monthly), _money(total + monthly)],
        f"{_money(principal)} × {rate}% ÷ 12 = 월 {_money(monthly)}; "
        f"{_money(monthly)} × {months}개월 = {_money(total)}",
        "원금과 금리가 같으면 월 이자는 일정하고 납부한 합계가 누적됩니다. "
        "일할 계산·수수료·금리 변화는 제외합니다.",
    )

    income, expenses, debt = (
        rng.choice([2400000, 3000000, 3500000]),
        rng.choice([1500000, 1800000, 2000000]),
        rng.choice([200000, 400000]),
    )
    interest = 20000
    net = income - expenses - debt - interest
    add(
        "cash_flow",
        f"가상 월 소득 {_money(income)}, 생활비 {_money(expenses)}, "
        f"기존 대출 상환 {_money(debt)}, 투자용 이자 {_money(interest)}입니다. "
        "다른 출입금이 없을 때 이번 달 남는 현금은 얼마일까요?",
        _money(net),
        [_money(net + interest), _money(net + debt)],
        f"{_money(income)} − {_money(expenses)} − {_money(debt)} "
        f"− {_money(interest)} = {_money(net)}",
        "생활비에는 별도로 적힌 대출 상환과 이자를 중복 포함하지 않습니다. "
        "투자 평가손익은 이 현금 계산에 더하거나 빼지 않습니다.",
    )

    cash, loss = rng.choice([3000000, 5000000, 8000000]), rng.choice([1000000, 2000000])
    add(
        "valuation",
        f"가상 현금 비상자금은 {_money(cash)}이고 "
        f"보유 주식에 평가손실 {_money(loss)}이 생겼습니다. "
        "매도·추가 납부·다른 수입과 지출이 없다면 현금은 얼마일까요?",
        _money(cash),
        [_money(cash - loss), _money(cash + loss)],
        f"{_money(cash)} + 현금 유입 0원 − 현금 지출 0원 = {_money(cash)}",
        "현금은 같지만 투자자산의 가치는 줄었습니다. 손실이 없다는 뜻이 아니며 "
        "이 사례에는 추가 담보 납부를 가정하지 않았습니다.",
    )

    principal, rate, rise = (
        rng.choice([4000000, 6000000, 10000000]),
        rng.choice([3, 6]),
        rng.choice([1, 2]),
    )
    before = _round(Decimal(principal) * rate / 100 / 12)
    after = _round(Decimal(principal) * (rate + rise) / 100 / 12)
    add(
        "rate_shock",
        f"가상 투자용 차입금 {_money(principal)}의 연금리가 "
        f"{rate}%에서 {rate + rise}%로 {rise}%p 올랐습니다. "
        "원금이 같을 때 월 이자는 얼마 증가할까요? 매월 원 단위 반올림합니다.",
        _money(after - before),
        [_money(after), _money(before)],
        f"변경 후 {_money(after)} − 변경 전 {_money(before)} "
        f"= {_money(after - before)}",
        "금리 상승폭의 %p는 두 금리의 차이입니다. 원금이 고정된 월 이자만 비교하며 "
        "기존 대출과 수수료는 포함하지 않습니다.",
    )

    peak, trough = rng.choice([(120, 84), (150, 75), (125, 100)])
    decline = (1 - Decimal(trough) / peak) * 100
    add(
        "drawdown",
        f"가상 관측 구간의 가격 고점은 {peak}이고 이후 저점은 {trough}입니다. "
        "이 고점 대비 하락률은 얼마일까요?",
        f"{_percent(decline)}% 하락",
        [f"{peak - trough}% 하락", f"{_percent(decline / 2)}% 하락"],
        f"({trough} ÷ {peak} − 1) × 100 = −{_percent(decline)}%",
        "가격 차이 자체가 아니라 고점을 분모로 사용합니다. "
        "관측 구간의 가상 낙폭이며 미래의 최악 상황을 뜻하지 않습니다.",
    )
    return rng.sample(questions, 5)
