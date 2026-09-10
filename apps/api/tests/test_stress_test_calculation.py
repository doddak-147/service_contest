from dataclasses import replace
from decimal import Decimal

import pytest

from app.features.stress_test.calculation import (
    CalculationInputError,
    FinancialProfile,
    calculate_scenario,
)


def make_profile() -> FinancialProfile:
    return FinancialProfile(
        monthly_income_krw=3_000_000,
        monthly_fixed_expenses_krw=1_800_000,
        emergency_fund_krw=0,
        existing_loan_balance_krw=0,
        monthly_debt_payment_krw=0,
        planned_investment_krw=15_000_000,
        equity_amount_krw=5_000_000,
        borrowed_amount_krw=10_000_000,
        annual_loan_rate=Decimal("0.06"),
    )


def calculate(
    profile: FinancialProfile,
    key: str,
    rate: str,
):
    return calculate_scenario(profile, key, "테스트", Decimal(rate))  # type: ignore[arg-type]


def test_leveraged_investment_down_20_matches_reference_values() -> None:
    result = calculate(make_profile(), "down_20", "-0.20")

    assert result.investment_loss_krw == 3_000_000
    assert result.loss_to_equity_ratio == Decimal("0.600000")
    assert result.net_investment_equity_krw == 2_000_000
    assert result.estimated_annual_interest_krw == 600_000
    assert result.estimated_monthly_interest_krw == 50_000
    assert result.loss_to_monthly_fixed_expenses == Decimal("1.666667")


def test_investment_without_borrowing_has_no_interest() -> None:
    profile = replace(
        make_profile(),
        planned_investment_krw=5_000_000,
        equity_amount_krw=5_000_000,
        borrowed_amount_krw=0,
    )

    result = calculate(profile, "down_20", "-0.20")

    assert result.estimated_annual_interest_krw == 0
    assert result.estimated_monthly_interest_krw == 0
    assert result.net_investment_equity_krw == 4_000_000


@pytest.mark.parametrize(
    ("key", "rate", "expected_loss", "expected_recovery"),
    [
        ("down_10", "-0.10", 1_500_000, Decimal("0.111111")),
        ("down_50", "-0.50", 7_500_000, Decimal("1.000000")),
    ],
)
def test_supported_decline_scenarios(
    key: str,
    rate: str,
    expected_loss: int,
    expected_recovery: Decimal,
) -> None:
    result = calculate(make_profile(), key, rate)

    assert result.investment_loss_krw == expected_loss
    assert result.recovery_required_rate == expected_recovery


def test_loss_can_exceed_equity_and_produce_negative_net_equity() -> None:
    profile = replace(
        make_profile(),
        equity_amount_krw=2_000_000,
        borrowed_amount_krw=13_000_000,
    )

    result = calculate(profile, "down_50", "-0.50")

    assert result.loss_to_equity_ratio == Decimal("3.750000")
    assert result.net_investment_equity_krw == -5_500_000


@pytest.mark.parametrize(
    ("updates", "field", "reason"),
    [
        (
            {"planned_investment_krw": 0},
            "planned_investment_krw",
            "MUST_BE_GREATER_THAN_ZERO",
        ),
        (
            {"equity_amount_krw": 0, "borrowed_amount_krw": 15_000_000},
            "equity_amount_krw",
            "MUST_BE_GREATER_THAN_ZERO",
        ),
        ({"borrowed_amount_krw": -1}, "borrowed_amount_krw", "MUST_BE_NON_NEGATIVE"),
        (
            {"annual_loan_rate": Decimal("-0.01")},
            "annual_loan_rate",
            "RATE_OUT_OF_RANGE",
        ),
        ({"monthly_income_krw": -1}, "monthly_income_krw", "MUST_BE_NON_NEGATIVE"),
        (
            {"monthly_fixed_expenses_krw": -1},
            "monthly_fixed_expenses_krw",
            "MUST_BE_NON_NEGATIVE",
        ),
    ],
)
def test_invalid_financial_inputs_are_rejected(
    updates: dict[str, object],
    field: str,
    reason: str,
) -> None:
    profile = replace(make_profile(), **updates)

    with pytest.raises(CalculationInputError) as exc_info:
        calculate(profile, "down_20", "-0.20")

    assert exc_info.value.field == field
    assert exc_info.value.reason == reason


def test_investment_composition_mismatch_is_rejected() -> None:
    profile = replace(make_profile(), borrowed_amount_krw=9_000_000)

    with pytest.raises(CalculationInputError) as exc_info:
        calculate(profile, "down_20", "-0.20")

    assert exc_info.value.field == "equity_amount_krw"
    assert exc_info.value.reason == "INVESTMENT_SUM_MISMATCH"


def test_wrong_rate_for_scenario_key_is_rejected() -> None:
    with pytest.raises(CalculationInputError) as exc_info:
        calculate(make_profile(), "down_10", "-0.20")

    assert exc_info.value.field == "scenario_key"
    assert exc_info.value.reason == "INVALID_SCENARIO_RATE"
