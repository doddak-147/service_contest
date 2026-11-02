"""Deterministic cash budget assumptions, independent of market valuations."""

from dataclasses import dataclass, replace
from decimal import ROUND_HALF_UP, Decimal
from typing import Literal

from app.features.stress_test.calculation import (
    CalculationInputError,
    FinancialProfile,
    ScenarioCalculation,
    calculate_scenario,
    validate_financial_profile,
)

RepaymentMethod = Literal["interest_only", "equal_principal"]


@dataclass(frozen=True, slots=True)
class CashFlowAssumptions:
    months: int = 6
    loan_term_months: int = 36
    repayment_method: RepaymentMethod = "interest_only"
    income_change_rate: Decimal = Decimal("0")
    expense_change_rate: Decimal = Decimal("0")
    loan_rate_change: Decimal = Decimal("0")
    price_change_rate: Decimal = Decimal("0")
    exchange_rate_change_rate: Decimal = Decimal("0")
    investment_currency: Literal["KRW", "USD"] = "KRW"


@dataclass(frozen=True, slots=True)
class MonthlyCashFlow:
    month: int
    income_krw: int
    fixed_expenses_krw: int
    existing_debt_payment_krw: int
    investment_interest_krw: int
    investment_principal_payment_krw: int
    monthly_net_cash_krw: int
    cash_balance_krw: int
    cash_shortfall_krw: int
    investment_loan_balance_krw: int
    cumulative_interest_krw: int


@dataclass(frozen=True, slots=True)
class CashFlowPath:
    monthly_points: tuple[MonthlyCashFlow, ...]
    total_interest_krw: int
    total_principal_paid_krw: int
    ending_cash_balance_krw: int
    ending_loan_balance_krw: int
    first_shortfall_month: int | None


@dataclass(frozen=True, slots=True)
class CashFlowCalculation:
    baseline: CashFlowPath
    shocked: CashFlowPath
    investment_effect: ScenarioCalculation


def _money(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _path(
    profile: FinancialProfile, assumptions: CashFlowAssumptions, *, shocked: bool
) -> CashFlowPath:
    income = _money(
        Decimal(profile.monthly_income_krw)
        * (1 + (assumptions.income_change_rate if shocked else 0))
    )
    expenses = _money(
        Decimal(profile.monthly_fixed_expenses_krw)
        * (1 + (assumptions.expense_change_rate if shocked else 0))
    )
    rate = profile.annual_loan_rate + (assumptions.loan_rate_change if shocked else 0)
    balance = profile.borrowed_amount_krw
    cash = profile.emergency_fund_krw
    total_interest = total_principal = 0
    first_shortfall = None
    points = []
    regular_principal = _money(Decimal(balance) / assumptions.loan_term_months)
    for month in range(1, assumptions.months + 1):
        interest = _money(Decimal(balance) * rate / 12)
        principal = 0
        if month == assumptions.loan_term_months:
            principal = balance
        elif assumptions.repayment_method == "equal_principal":
            principal = min(balance, regular_principal)
        balance -= principal
        net = (
            income - expenses - profile.monthly_debt_payment_krw - interest - principal
        )
        cash += net
        total_interest += interest
        total_principal += principal
        if cash < 0 and first_shortfall is None:
            first_shortfall = month
        points.append(
            MonthlyCashFlow(
                month,
                income,
                expenses,
                profile.monthly_debt_payment_krw,
                interest,
                principal,
                net,
                cash,
                max(-cash, 0),
                balance,
                total_interest,
            )
        )
    return CashFlowPath(
        tuple(points), total_interest, total_principal, cash, balance, first_shortfall
    )


def calculate_cash_flow(
    profile: FinancialProfile, assumptions: CashFlowAssumptions
) -> CashFlowCalculation:
    validate_financial_profile(profile)
    if assumptions.months not in (3, 6, 12):
        raise CalculationInputError("months", "UNSUPPORTED_MONTHS")
    if not 1 <= assumptions.loan_term_months <= 360:
        raise CalculationInputError("loan_term_months", "OUT_OF_RANGE")
    if assumptions.repayment_method not in ("interest_only", "equal_principal"):
        raise CalculationInputError("repayment_method", "UNSUPPORTED_METHOD")
    bounds = {
        "income_change_rate": (Decimal("-1"), Decimal("0")),
        "expense_change_rate": (Decimal("0"), Decimal("1")),
        "loan_rate_change": (Decimal("0"), 1 - profile.annual_loan_rate),
        "price_change_rate": (Decimal("-1"), Decimal("1")),
        "exchange_rate_change_rate": (Decimal("-0.5"), Decimal("0.5")),
    }
    for field, (low, high) in bounds.items():
        value = getattr(assumptions, field)
        if not value.is_finite() or not low <= value <= high:
            raise CalculationInputError(field, "RATE_OUT_OF_RANGE")
    if assumptions.investment_currency not in ("KRW", "USD"):
        raise CalculationInputError("investment_currency", "UNSUPPORTED_CURRENCY")
    if (
        assumptions.investment_currency == "KRW"
        and assumptions.exchange_rate_change_rate
    ):
        raise CalculationInputError("exchange_rate_change_rate", "USD_ONLY")
    for field in profile.__dataclass_fields__:
        if field.endswith("_krw") and getattr(profile, field) > 10**15:
            raise CalculationInputError(field, "AMOUNT_TOO_LARGE")
    adjusted = replace(
        profile,
        annual_loan_rate=profile.annual_loan_rate + assumptions.loan_rate_change,
    )
    effect = calculate_scenario(
        adjusted,
        "custom",
        "즉시 주가·환율 충격 가정",
        assumptions.price_change_rate,
        assumptions.exchange_rate_change_rate,
    )
    return CashFlowCalculation(
        _path(profile, assumptions, shocked=False),
        _path(profile, assumptions, shocked=True),
        effect,
    )
