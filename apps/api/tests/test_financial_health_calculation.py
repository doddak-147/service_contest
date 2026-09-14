from dataclasses import replace
from decimal import Decimal

import pytest

from app.features.financial_health.calculation import (
    FinancialHealthInputError,
    calculate_financial_health,
)
from app.features.stress_test.calculation import FinancialProfile


def make_profile() -> FinancialProfile:
    # docs/API_CONTRACT.md의 기준 예시를 그대로 테스트 기준값으로 사용한다.
    return FinancialProfile(
        monthly_income_krw=3_000_000,
        monthly_fixed_expenses_krw=1_500_000,
        emergency_fund_krw=5_000_000,
        existing_loan_balance_krw=10_000_000,
        monthly_debt_payment_krw=400_000,
        planned_investment_krw=10_000_000,
        equity_amount_krw=6_000_000,
        borrowed_amount_krw=4_000_000,
        annual_loan_rate=Decimal("0.06"),
    )


def test_financial_health_matches_contract_reference_values() -> None:
    result = calculate_financial_health(make_profile())

    assert result.monthly_surplus_krw == 1_100_000
    assert result.emergency_runway_months == Decimal("2.631579")
    assert result.leverage_ratio == Decimal("0.400000")
    assert result.estimated_monthly_interest_krw == 20_000
    assert result.reported_total_debt_krw == 14_000_000
    assert result.unavailable_reasons == ()


def test_negative_monthly_surplus_is_a_valid_result() -> None:
    profile = replace(
        make_profile(),
        monthly_income_krw=1_000_000,
        monthly_fixed_expenses_krw=1_200_000,
        monthly_debt_payment_krw=300_000,
    )

    result = calculate_financial_health(profile)

    # 음수 현금흐름도 사용자의 현재 상태를 보여주는 결과이므로 입력 오류로 숨기지 않는다.
    assert result.monthly_surplus_krw == -500_000


def test_zero_essential_outflow_returns_null_with_reason() -> None:
    profile = replace(
        make_profile(),
        monthly_fixed_expenses_krw=0,
        monthly_debt_payment_krw=0,
    )

    result = calculate_financial_health(profile)

    assert result.emergency_runway_months is None
    assert result.unavailable_reasons == ("ZERO_ESSENTIAL_OUTFLOW",)


def test_zero_equity_is_allowed_for_financial_health() -> None:
    profile = replace(
        make_profile(),
        equity_amount_krw=0,
        borrowed_amount_krw=10_000_000,
    )

    result = calculate_financial_health(profile)

    assert result.leverage_ratio == Decimal("1.000000")
    assert result.estimated_monthly_interest_krw == 50_000


@pytest.mark.parametrize(
    ("updates", "field", "reason"),
    [
        (
            {"monthly_income_krw": -1},
            "monthly_income_krw",
            "MUST_BE_NON_NEGATIVE",
        ),
        (
            {"equity_amount_krw": -1},
            "equity_amount_krw",
            "MUST_BE_NON_NEGATIVE",
        ),
        (
            {"planned_investment_krw": 0},
            "planned_investment_krw",
            "MUST_BE_GREATER_THAN_ZERO",
        ),
        (
            {"annual_loan_rate": Decimal("1.01")},
            "annual_loan_rate",
            "RATE_OUT_OF_RANGE",
        ),
        (
            {"borrowed_amount_krw": 3_000_000},
            "equity_amount_krw",
            "INVESTMENT_SUM_MISMATCH",
        ),
    ],
)
def test_invalid_inputs_are_rejected(
    updates: dict[str, object], field: str, reason: str
) -> None:
    profile = replace(make_profile(), **updates)

    with pytest.raises(FinancialHealthInputError) as exc_info:
        calculate_financial_health(profile)

    assert exc_info.value.field == field
    assert exc_info.value.reason == reason
