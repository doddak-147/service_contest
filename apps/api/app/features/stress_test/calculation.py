from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal
from typing import Literal, TypeAlias

ScenarioKey: TypeAlias = Literal[
    "up_20",
    "flat",
    "down_10",
    "down_20",
    "down_30",
    "down_40",
    "down_50",
    "historical_mdd",
    "custom",
]

MONEY_QUANTUM = Decimal("1")
RATIO_QUANTUM = Decimal("0.000001")

FIXED_SCENARIOS: tuple[tuple[ScenarioKey, str, Decimal], ...] = (
    ("up_20", "20% 상승", Decimal("0.20")),
    ("flat", "보합", Decimal("0")),
    ("down_10", "10% 하락", Decimal("-0.10")),
    ("down_20", "20% 하락", Decimal("-0.20")),
    ("down_30", "30% 하락", Decimal("-0.30")),
    ("down_40", "40% 하락", Decimal("-0.40")),
    ("down_50", "50% 하락", Decimal("-0.50")),
)


@dataclass(frozen=True, slots=True)
class FinancialProfile:
    monthly_income_krw: int
    monthly_fixed_expenses_krw: int
    emergency_fund_krw: int
    existing_loan_balance_krw: int
    monthly_debt_payment_krw: int
    planned_investment_krw: int
    equity_amount_krw: int
    borrowed_amount_krw: int
    annual_loan_rate: Decimal


@dataclass(frozen=True, slots=True)
class ScenarioCalculation:
    scenario_key: ScenarioKey
    label: str
    assumed_return_rate: Decimal
    price_change_rate: Decimal | None
    exchange_rate_change_rate: Decimal | None
    projected_investment_value_krw: int
    investment_pnl_krw: int
    investment_loss_krw: int
    reported_total_debt_krw: int
    net_investment_equity_krw: int
    loss_to_equity_ratio: Decimal | None
    loss_to_emergency_fund_ratio: Decimal | None
    loss_to_monthly_fixed_expenses: Decimal | None
    estimated_annual_interest_krw: int
    estimated_monthly_interest_krw: int
    recovery_required_rate: Decimal | None
    unavailable_reasons: tuple[str, ...]


class CalculationInputError(ValueError):
    def __init__(self, field: str, reason: str) -> None:
        super().__init__(reason)
        self.field = field
        self.reason = reason


def _round_money(value: Decimal) -> int:
    return int(value.quantize(MONEY_QUANTUM, rounding=ROUND_HALF_UP))


def _round_ratio(value: Decimal) -> Decimal:
    return value.quantize(RATIO_QUANTUM, rounding=ROUND_HALF_UP)


def validate_financial_profile(profile: FinancialProfile) -> None:
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
            raise CalculationInputError(field, "MUST_BE_NON_NEGATIVE")

    if profile.planned_investment_krw <= 0:
        raise CalculationInputError(
            "planned_investment_krw", "MUST_BE_GREATER_THAN_ZERO"
        )
    if not profile.annual_loan_rate.is_finite() or not (
        Decimal("0") <= profile.annual_loan_rate <= Decimal("1")
    ):
        raise CalculationInputError("annual_loan_rate", "RATE_OUT_OF_RANGE")
    if (
        profile.equity_amount_krw + profile.borrowed_amount_krw
        != profile.planned_investment_krw
    ):
        raise CalculationInputError(
            "equity_amount_krw", "INVESTMENT_SUM_MISMATCH"
        )


def _validate_scenario(
    scenario_key: ScenarioKey,
    assumed_return_rate: Decimal,
) -> None:
    if not assumed_return_rate.is_finite():
        field = (
            "custom_return_rate"
            if scenario_key == "custom"
            else "historical_mdd_rate"
        )
        raise CalculationInputError(field, "INVALID_SCENARIO_RATE")

    if scenario_key == "custom":
        if not Decimal("-1") <= assumed_return_rate <= Decimal("1"):
            raise CalculationInputError("custom_return_rate", "RATE_OUT_OF_RANGE")
        return

    if scenario_key == "historical_mdd":
        if not Decimal("-1") <= assumed_return_rate <= Decimal("0"):
            raise CalculationInputError(
                "historical_mdd_rate", "INVALID_SCENARIO_RATE"
            )
        return

    expected_rates = {key: rate for key, _label, rate in FIXED_SCENARIOS}
    if expected_rates.get(scenario_key) != assumed_return_rate:
        raise CalculationInputError("scenario_key", "INVALID_SCENARIO_RATE")


def calculate_scenario(
    profile: FinancialProfile,
    scenario_key: ScenarioKey,
    label: str,
    assumed_return_rate: Decimal,
    exchange_rate_change_rate: Decimal = Decimal("0"),
) -> ScenarioCalculation:
    validate_financial_profile(profile)
    _validate_scenario(scenario_key, assumed_return_rate)
    if (
        not exchange_rate_change_rate.is_finite()
        or not Decimal("-0.5") <= exchange_rate_change_rate <= Decimal("0.5")
    ):
        raise CalculationInputError(
            "exchange_rate_change_rate", "RATE_OUT_OF_RANGE"
        )

    price_change_rate = assumed_return_rate
    if scenario_key == "historical_mdd":
        # Historical MDD is already based on KRW-converted prices.
        fx_change: Decimal | None = None
        displayed_price_change: Decimal | None = None
    else:
        fx_change = exchange_rate_change_rate
        displayed_price_change = price_change_rate
        assumed_return_rate = (
            (Decimal("1") + price_change_rate)
            * (Decimal("1") + exchange_rate_change_rate)
            - Decimal("1")
        )

    investment_amount = Decimal(profile.planned_investment_krw)
    investment_pnl = investment_amount * assumed_return_rate
    investment_loss = max(-investment_pnl, Decimal("0"))
    projected_value = investment_amount + investment_pnl
    annual_interest = (
        Decimal(profile.borrowed_amount_krw) * profile.annual_loan_rate
    )

    unavailable_reasons: list[str] = []
    loss_to_equity_ratio: Decimal | None
    loss_to_emergency_fund_ratio: Decimal | None
    loss_to_monthly_fixed_expenses: Decimal | None

    if profile.equity_amount_krw == 0:
        loss_to_equity_ratio = None
        unavailable_reasons.append("ZERO_EQUITY")
    else:
        loss_to_equity_ratio = _round_ratio(
            investment_loss / Decimal(profile.equity_amount_krw)
        )

    if profile.emergency_fund_krw == 0:
        loss_to_emergency_fund_ratio = None
        unavailable_reasons.append("ZERO_EMERGENCY_FUND")
    else:
        loss_to_emergency_fund_ratio = _round_ratio(
            investment_loss / Decimal(profile.emergency_fund_krw)
        )

    if profile.monthly_fixed_expenses_krw == 0:
        loss_to_monthly_fixed_expenses = None
        unavailable_reasons.append("ZERO_FIXED_EXPENSES")
    else:
        loss_to_monthly_fixed_expenses = _round_ratio(
            investment_loss / Decimal(profile.monthly_fixed_expenses_krw)
        )

    if investment_loss == investment_amount:
        recovery_required_rate = None
        unavailable_reasons.append("NO_FINITE_RECOVERY_RATE")
    else:
        recovery_required_rate = _round_ratio(
            investment_loss / (investment_amount - investment_loss)
        )

    return ScenarioCalculation(
        scenario_key=scenario_key,
        label=label,
        assumed_return_rate=_round_ratio(assumed_return_rate),
        price_change_rate=(
            _round_ratio(displayed_price_change)
            if displayed_price_change is not None
            else None
        ),
        exchange_rate_change_rate=(
            _round_ratio(fx_change) if fx_change is not None else None
        ),
        projected_investment_value_krw=_round_money(projected_value),
        investment_pnl_krw=_round_money(investment_pnl),
        investment_loss_krw=_round_money(investment_loss),
        reported_total_debt_krw=(
            profile.existing_loan_balance_krw + profile.borrowed_amount_krw
        ),
        net_investment_equity_krw=_round_money(
            projected_value - Decimal(profile.borrowed_amount_krw)
        ),
        loss_to_equity_ratio=loss_to_equity_ratio,
        loss_to_emergency_fund_ratio=loss_to_emergency_fund_ratio,
        loss_to_monthly_fixed_expenses=loss_to_monthly_fixed_expenses,
        estimated_annual_interest_krw=_round_money(annual_interest),
        estimated_monthly_interest_krw=_round_money(
            annual_interest / Decimal("12")
        ),
        recovery_required_rate=recovery_required_rate,
        unavailable_reasons=tuple(unavailable_reasons),
    )


def calculate_stress_tests(
    profile: FinancialProfile,
    historical_mdd_rate: Decimal | None,
    exchange_rate_change_rate: Decimal = Decimal("0"),
    custom_return_rate: Decimal | None = None,
) -> tuple[ScenarioCalculation, ...]:
    scenarios = [
        calculate_scenario(
            profile,
            key,
            label,
            rate,
            exchange_rate_change_rate,
        )
        for key, label, rate in FIXED_SCENARIOS
    ]
    if historical_mdd_rate is not None:
        scenarios.append(
            calculate_scenario(
                profile,
                "historical_mdd",
                "과거 최대낙폭 재현",
                historical_mdd_rate,
            )
        )
    if custom_return_rate is not None:
        _validate_scenario("custom", custom_return_rate)
        sign = "+" if custom_return_rate > 0 else ""
        percent = (custom_return_rate * 100).normalize()
        label = f"직접 입력 ({sign}{percent:f}%)"
        scenarios.append(
            calculate_scenario(
                profile,
                "custom",
                label,
                custom_return_rate,
                exchange_rate_change_rate,
            )
        )
    return tuple(scenarios)
