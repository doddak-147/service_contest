import re
from decimal import ROUND_HALF_UP, Decimal

from app.features.combined_report.schemas import (
    ExplanationInput,
    ExplanationResult,
)
from app.integrations.llm.base import ExplanationDraft

CAUTION = (
    "가정된 가격 충격을 설명한 결과이며 투자 추천이나 미래 가격 예측이 아닙니다."
)
PLACEHOLDER_PATTERN = re.compile(r"\{\{([a-z_]+)\}\}")
DIGIT_PATTERN = re.compile(r"[0-9０-９]")
RAW_NUMBER_UNIT_PATTERN = re.compile(r"(?:%|원|퍼센트|개월|배)")
FORBIDDEN_PHRASES = (
    "매수",
    "매도",
    "투자해도",
    "투자하지 마",
    "투자를 추천",
    "투자 가능",
    "미래 주가",
    "가격을 예측",
    "수익을 보장",
    "권장",
    "좋은 투자",
    "투자에 적합",
    "감당할 수",
    "피하는 것이",
    "오를 것",
    "내릴 것",
)


class UnsafeExplanationError(ValueError):
    """Raised when an LLM draft can change facts or imply investment advice."""


def _decimal(value: float) -> Decimal:
    return Decimal(str(value))


def _format_krw(value: int) -> str:
    return f"{value:,}원"


def _format_percent(value: float | None) -> str:
    if value is None:
        return "계산 불가"
    percent = (_decimal(value) * Decimal("100")).quantize(
        Decimal("0.1"), rounding=ROUND_HALF_UP
    )
    return f"{percent}%"


def _format_signed_percent(value: float | None) -> str:
    if value is None:
        return "계산 불가"
    formatted = _format_percent(value)
    return f"+{formatted}" if value > 0 else formatted


def _format_months(value: float | None) -> str:
    if value is None:
        return "계산 불가"
    months = _decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return f"약 {months}개월"


def _replacement_values(payload: ExplanationInput) -> dict[str, str]:
    return {
        "assumed_return_rate": _format_signed_percent(
            payload.assumed_return_rate
        ),
        "investment_loss_krw": _format_krw(payload.investment_loss_krw),
        "loss_to_equity_ratio": _format_percent(
            payload.loss_to_equity_ratio
        ),
        "loss_to_emergency_fund_ratio": _format_percent(
            payload.loss_to_emergency_fund_ratio
        ),
        "loss_to_monthly_fixed_expenses": _format_months(
            payload.loss_to_monthly_fixed_expenses
        ),
        "net_investment_equity_krw": _format_krw(
            payload.net_investment_equity_krw
        ),
        "estimated_monthly_interest_krw": _format_krw(
            payload.estimated_monthly_interest_krw
        ),
        "market_max_drawdown_rate": _format_signed_percent(
            payload.market_max_drawdown_rate
        ),
    }


def _render(template: str, payload: ExplanationInput) -> str:
    replacements = _replacement_values(payload)
    return PLACEHOLDER_PATTERN.sub(
        lambda match: replacements[match.group(1)], template
    )


def build_template_explanation(payload: ExplanationInput) -> ExplanationResult:
    if payload.scenario_key == "historical_mdd":
        template = (
            "과거 최대낙폭과 같은 가격 충격을 가정하면 예상 투자손실은 "
            "{{investment_loss_krw}}이며 자기자본 대비 "
            "{{loss_to_equity_ratio}}입니다. 손실 후 순투자지분은 "
            "{{net_investment_equity_krw}}입니다."
        )
    else:
        template = (
            "{{assumed_return_rate}} 가격 변화를 가정하면 예상 투자손실은 "
            "{{investment_loss_krw}}이며, 월 고정지출 "
            "{{loss_to_monthly_fixed_expenses}}에 해당합니다."
        )
    return ExplanationResult(
        source="template",
        summary=_render(template, payload),
        caution=CAUTION,
    )


def build_llm_explanation(
    payload: ExplanationInput,
    draft: ExplanationDraft,
) -> ExplanationResult:
    summary = draft.summary.strip()
    if not summary or len(summary) > 600:
        raise UnsafeExplanationError("INVALID_LENGTH")
    if DIGIT_PATTERN.search(summary):
        raise UnsafeExplanationError("NEW_NUMBER")
    if RAW_NUMBER_UNIT_PATTERN.search(summary):
        raise UnsafeExplanationError("NEW_NUMBER")
    if any(phrase in summary for phrase in FORBIDDEN_PHRASES):
        raise UnsafeExplanationError("PROHIBITED_ADVICE")

    placeholders = PLACEHOLDER_PATTERN.findall(summary)
    allowed = set(_replacement_values(payload))
    if not placeholders or any(value not in allowed for value in placeholders):
        raise UnsafeExplanationError("INVALID_PLACEHOLDER")

    rendered = _render(summary, payload)
    if "{{" in rendered or "}}" in rendered:
        raise UnsafeExplanationError("INVALID_PLACEHOLDER")
    return ExplanationResult(source="llm", summary=rendered, caution=CAUTION)
