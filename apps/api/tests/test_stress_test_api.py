from copy import deepcopy
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.shared.config import Settings

TEST_ORIGIN = "http://localhost:8081"


def make_client() -> TestClient:
    app = create_app(Settings(app_env="test", cors_origins=(TEST_ORIGIN,)))
    return TestClient(app)


def valid_request() -> dict[str, Any]:
    return {
        "financial_profile": {
            "monthly_income_krw": 3_000_000,
            "monthly_fixed_expenses_krw": 1_800_000,
            "emergency_fund_krw": 0,
            "existing_loan_balance_krw": 0,
            "monthly_debt_payment_krw": 0,
            "planned_investment_krw": 15_000_000,
            "equity_amount_krw": 5_000_000,
            "borrowed_amount_krw": 10_000_000,
            "annual_loan_rate": 0.06,
        },
        "historical_mdd_rate": None,
    }


def test_stress_test_endpoint_returns_server_calculations() -> None:
    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=valid_request())

    assert response.status_code == 200
    results = response.json()
    assert [result["scenario_key"] for result in results] == [
        "up_20",
        "flat",
        "down_10",
        "down_20",
        "down_30",
        "down_40",
        "down_50",
    ]

    down_20 = next(result for result in results if result["scenario_key"] == "down_20")
    assert down_20["investment_loss_krw"] == 3_000_000
    assert down_20["loss_to_equity_ratio"] == 0.6
    assert down_20["net_investment_equity_krw"] == 2_000_000
    assert down_20["estimated_annual_interest_krw"] == 600_000
    assert down_20["estimated_monthly_interest_krw"] == 50_000
    assert down_20["loss_to_monthly_fixed_expenses"] == 1.666667
    assert response.headers["X-Request-ID"]


@pytest.mark.parametrize(
    ("field", "value", "expected_reason"),
    [
        ("planned_investment_krw", 0, "MUST_BE_GREATER_THAN_ZERO"),
        ("borrowed_amount_krw", -1, "MUST_BE_NON_NEGATIVE"),
        ("annual_loan_rate", -0.01, "RATE_OUT_OF_RANGE"),
        ("monthly_income_krw", -1, "MUST_BE_NON_NEGATIVE"),
        ("monthly_fixed_expenses_krw", -1, "MUST_BE_NON_NEGATIVE"),
    ],
)
def test_invalid_financial_input_uses_common_error_response(
    field: str,
    value: int | float,
    expected_reason: str,
) -> None:
    request = deepcopy(valid_request())
    request["financial_profile"][field] = value

    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=request)

    body = response.json()
    assert response.status_code == 422
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["field_errors"] == [
        {"field": field, "reason": expected_reason}
    ]
    assert body["error"]["request_id"] == response.headers["X-Request-ID"]


def test_zero_equity_is_rejected() -> None:
    request = deepcopy(valid_request())
    request["financial_profile"]["equity_amount_krw"] = 0
    request["financial_profile"]["borrowed_amount_krw"] = 15_000_000

    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["field_errors"] == [
        {
            "field": "equity_amount_krw",
            "reason": "MUST_BE_GREATER_THAN_ZERO",
        }
    ]


def test_investment_composition_mismatch_is_rejected() -> None:
    request = deepcopy(valid_request())
    request["financial_profile"]["borrowed_amount_krw"] = 9_000_000

    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["field_errors"] == [
        {"field": "equity_amount_krw", "reason": "INVESTMENT_SUM_MISMATCH"}
    ]


def test_invalid_historical_decline_rate_is_rejected() -> None:
    request = valid_request()
    request["historical_mdd_rate"] = 0.1

    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["field_errors"] == [
        {"field": "historical_mdd_rate", "reason": "INVALID_SCENARIO_RATE"}
    ]


def test_wrong_json_type_uses_common_error_response() -> None:
    request = valid_request()
    request["financial_profile"]["planned_investment_krw"] = "15000000"

    with make_client() as client:
        response = client.post("/api/v1/stress-tests/analyze", json=request)

    body = response.json()
    assert response.status_code == 422
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["field_errors"]
