from dataclasses import asdict, replace
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.features.stress_test.calculation import CalculationInputError, FinancialProfile
from app.features.stress_test.cash_flow import CashFlowAssumptions, calculate_cash_flow
from app.main import create_app
from app.shared.config import Settings

PROFILE = FinancialProfile(
    3000000,
    1500000,
    5000000,
    10000000,
    400000,
    10000000,
    6000000,
    4000000,
    Decimal("0.06"),
)


@pytest.mark.parametrize("months", [3, 6, 12])
def test_fixed_cash_budget_and_cumulative_interest(months: int) -> None:
    result = calculate_cash_flow(PROFILE, CashFlowAssumptions(months=months))
    assert result.baseline == result.shocked
    assert result.baseline.total_interest_krw == 20000 * months
    assert result.baseline.ending_cash_balance_krw == 5000000 + 1080000 * months
    assert result.baseline.ending_loan_balance_krw == 4000000
    assert result.baseline.first_shortfall_month is None


def test_combined_living_shocks_are_cash_only_and_do_not_spend_market_losses() -> None:
    assumptions = CashFlowAssumptions(
        income_change_rate=Decimal("-0.2"),
        expense_change_rate=Decimal("0.1"),
        loan_rate_change=Decimal("0.02"),
        price_change_rate=Decimal("-1"),
    )
    result = calculate_cash_flow(PROFILE, assumptions)
    first = result.shocked.monthly_points[0]
    assert (first.income_krw, first.fixed_expenses_krw) == (2400000, 1650000)
    assert first.investment_interest_krw == 26667
    assert first.monthly_net_cash_krw == 323333
    assert result.investment_effect.investment_loss_krw == 10000000
    assert result.investment_effect.recovery_required_rate is None
    flat = calculate_cash_flow(
        PROFILE, replace(assumptions, price_change_rate=Decimal(0))
    )
    assert result.shocked == flat.shocked


def test_balloon_payment_and_equal_principal_reconcile_exactly() -> None:
    balloon = calculate_cash_flow(
        PROFILE, CashFlowAssumptions(months=3, loan_term_months=3)
    )
    assert (
        balloon.baseline.monthly_points[-1].investment_principal_payment_krw == 4000000
    )
    assert balloon.baseline.ending_cash_balance_krw == 4240000
    equal = calculate_cash_flow(
        PROFILE,
        CashFlowAssumptions(
            months=3,
            loan_term_months=3,
            repayment_method="equal_principal",
        ),
    )
    assert [
        p.investment_principal_payment_krw for p in equal.baseline.monthly_points
    ] == [
        1333333,
        1333333,
        1333334,
    ]
    assert equal.baseline.total_principal_paid_krw == 4000000
    assert equal.baseline.ending_loan_balance_krw == 0
    assert equal.baseline.total_interest_krw == 40000


def test_zero_income_fund_and_rate_do_not_create_implicit_borrowing() -> None:
    profile = FinancialProfile(0, 0, 0, 0, 0, 3, 0, 3, Decimal(0))
    result = calculate_cash_flow(
        profile,
        CashFlowAssumptions(
            months=3,
            loan_term_months=2,
            repayment_method="equal_principal",
        ),
    )
    assert [p.cash_balance_krw for p in result.shocked.monthly_points] == [-2, -3, -3]
    assert result.shocked.first_shortfall_month == 1
    assert result.shocked.ending_loan_balance_krw == 0
    assert result.shocked.total_interest_krw == 0
    assert result.investment_effect.loss_to_equity_ratio is None


@pytest.mark.parametrize(
    "field,value",
    [
        ("income_change_rate", Decimal("-1.01")),
        ("expense_change_rate", Decimal("NaN")),
        ("loan_rate_change", Decimal("0.95")),
        ("months", 4),
        ("loan_term_months", 0),
        ("exchange_rate_change_rate", Decimal("0.1")),
    ],
)
def test_invalid_assumptions_are_rejected(field: str, value: object) -> None:
    with pytest.raises(CalculationInputError):
        calculate_cash_flow(PROFILE, replace(CashFlowAssumptions(), **{field: value}))


def test_cash_flow_api_contract_and_invalid_extra_fields() -> None:
    profile = asdict(PROFILE)
    profile["annual_loan_rate"] = float(PROFILE.annual_loan_rate)
    with TestClient(create_app(Settings(app_env="test", cors_origins=()))) as client:
        payload = {"financial_profile": profile, "months": 6}
        response = client.post("/api/v1/stress-tests/cash-flow", json=payload)
        assert response.status_code == 200
        body = response.json()
        assert body["initial_cash_krw"] == 5000000
        assert len(body["baseline"]["monthly_points"]) == 6
        assert body["baseline"]["ending_cash_balance_krw"] == 11480000
        assert isinstance(body["shocked"]["total_interest_krw"], int)
        assert body["investment_effect"]["scenario_key"] == "custom"
        assert (
            client.post(
                "/api/v1/stress-tests/cash-flow", json={**payload, "unknown": 1}
            ).status_code
            == 422
        )
        assert (
            client.post(
                "/api/v1/stress-tests/cash-flow", json={**payload, "months": True}
            ).status_code
            == 422
        )
