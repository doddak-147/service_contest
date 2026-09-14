from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from app.features.stress_test.calculation import FinancialProfile

MONEY_QUANTUM = Decimal("1")
RATIO_QUANTUM = Decimal("0.000001")


@dataclass(frozen=True, slots=True)
class FinancialHealthCalculation:
    """개인 금융체력 분석에서 서버가 결정론적으로 계산한 결과다."""

    monthly_surplus_krw: int
    emergency_runway_months: Decimal | None
    leverage_ratio: Decimal | None
    estimated_monthly_interest_krw: int
    reported_total_debt_krw: int
    unavailable_reasons: tuple[str, ...]


class FinancialHealthInputError(ValueError):
    """공통 API 오류 응답으로 변환하기 위한 계산 입력 오류다."""

    def __init__(self, field: str, reason: str) -> None:
        super().__init__(reason)
        self.field = field
        self.reason = reason


def _round_money(value: Decimal) -> int:
    """금액은 API 계약에 맞춰 원 단위 ROUND_HALF_UP으로 반올림한다."""

    return int(value.quantize(MONEY_QUANTUM, rounding=ROUND_HALF_UP))


def _round_ratio(value: Decimal) -> Decimal:
    """비율/개월 값은 직렬화 직전에 소수점 6자리로 반올림한다."""

    return value.quantize(RATIO_QUANTUM, rounding=ROUND_HALF_UP)


def validate_financial_health_profile(profile: FinancialProfile) -> None:
    """Financial Health에서 필요한 입력 규칙만 검증한다.

    Stress Test는 손실/자기자본 비율 때문에 자기자본 0원을 거부하지만,
    Financial Health는 완전 차입 상태도 leverage_ratio=1로 계산할 수 있다.
    따라서 Stress Test의 검증 함수를 그대로 재사용하지 않는다.
    """

    non_negative_fields = (
        "monthly_income_krw",
        "monthly_fixed_expenses_krw",
        "emergency_fund_krw",
        "existing_loan_balance_krw",
        "monthly_debt_payment_krw",
        "equity_amount_krw",
        "borrowed_amount_krw",
    )
    for field in non_negative_fields:
        if getattr(profile, field) < 0:
            raise FinancialHealthInputError(field, "MUST_BE_NON_NEGATIVE")

    if profile.planned_investment_krw <= 0:
        raise FinancialHealthInputError(
            "planned_investment_krw", "MUST_BE_GREATER_THAN_ZERO"
        )

    if not profile.annual_loan_rate.is_finite() or not (
        Decimal("0") <= profile.annual_loan_rate <= Decimal("1")
    ):
        raise FinancialHealthInputError("annual_loan_rate", "RATE_OUT_OF_RANGE")

    if (
        profile.equity_amount_krw + profile.borrowed_amount_krw
        != profile.planned_investment_krw
    ):
        raise FinancialHealthInputError(
            "equity_amount_krw", "INVESTMENT_SUM_MISMATCH"
        )


def calculate_financial_health(
    profile: FinancialProfile,
) -> FinancialHealthCalculation:
    """개인 금융체력을 계산한다.

    LLM이나 Flutter에서 계산하지 않도록 모든 금융 계산을 서버의 순수 함수에
    모은다. 입력을 저장하거나 외부 API를 호출하지 않는다.
    """

    validate_financial_health_profile(profile)

    # API_CONTRACT/DATA_MODEL의 정의대로 신규 투자대출 이자는 월 잉여현금에서
    # 빼지 않는다. 이자는 아래 estimated_monthly_interest_krw로 별도 표시한다.
    monthly_surplus = (
        profile.monthly_income_krw
        - profile.monthly_fixed_expenses_krw
        - profile.monthly_debt_payment_krw
    )

    essential_monthly_outflow = (
        profile.monthly_fixed_expenses_krw + profile.monthly_debt_payment_krw
    )
    unavailable_reasons: list[str] = []

    if essential_monthly_outflow == 0:
        # 분모가 0이면 0개월로 꾸미지 않고 null + 사유 코드를 반환한다.
        emergency_runway_months = None
        unavailable_reasons.append("ZERO_ESSENTIAL_OUTFLOW")
    else:
        emergency_runway_months = _round_ratio(
            Decimal(profile.emergency_fund_krw) / Decimal(essential_monthly_outflow)
        )

    # planned_investment_krw > 0은 위 검증에서 보장되므로 정상 요청에서는 항상 계산된다.
    leverage_ratio = _round_ratio(
        Decimal(profile.borrowed_amount_krw) / Decimal(profile.planned_investment_krw)
    )

    estimated_monthly_interest = (
        Decimal(profile.borrowed_amount_krw)
        * profile.annual_loan_rate
        / Decimal("12")
    )

    return FinancialHealthCalculation(
        monthly_surplus_krw=monthly_surplus,
        emergency_runway_months=emergency_runway_months,
        leverage_ratio=leverage_ratio,
        estimated_monthly_interest_krw=_round_money(estimated_monthly_interest),
        reported_total_debt_krw=(
            profile.existing_loan_balance_krw + profile.borrowed_amount_krw
        ),
        unavailable_reasons=tuple(unavailable_reasons),
    )
