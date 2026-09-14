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
    # docs/API_CONTRACT.md의 FinancialProfileInput 예시와 동일하다.
    return {
        "monthly_income_krw": 3_000_000,
        "monthly_fixed_expenses_krw": 1_500_000,
        "emergency_fund_krw": 5_000_000,
        "existing_loan_balance_krw": 10_000_000,
        "monthly_debt_payment_krw": 400_000,
        "planned_investment_krw": 10_000_000,
        "equity_amount_krw": 6_000_000,
        "borrowed_amount_krw": 4_000_000,
        "annual_loan_rate": 0.06,
    }


def test_financial_health_endpoint_returns_contract_result() -> None:
    with make_client() as client:
        response = client.post("/api/v1/financial-health/analyze", json=valid_request())

    assert response.status_code == 200
    assert response.json() == {
        "monthly_surplus_krw": 1_100_000,
        "emergency_runway_months": 2.631579,
        "leverage_ratio": 0.4,
        "estimated_monthly_interest_krw": 20_000,
        "reported_total_debt_krw": 14_000_000,
        "unavailable_reasons": [],
    }
    assert response.headers["X-Request-ID"]


def test_zero_essential_outflow_returns_null_and_reason() -> None:
    request = valid_request()
    request["monthly_fixed_expenses_krw"] = 0
    request["monthly_debt_payment_krw"] = 0

    with make_client() as client:
        response = client.post("/api/v1/financial-health/analyze", json=request)

    assert response.status_code == 200
    body = response.json()
    assert body["emergency_runway_months"] is None
    assert body["unavailable_reasons"] == ["ZERO_ESSENTIAL_OUTFLOW"]


def test_zero_equity_is_allowed_for_financial_health_endpoint() -> None:
    request = valid_request()
    request["equity_amount_krw"] = 0
    request["borrowed_amount_krw"] = 10_000_000

    with make_client() as client:
        response = client.post("/api/v1/financial-health/analyze", json=request)

    assert response.status_code == 200
    assert response.json()["leverage_ratio"] == 1.0


@pytest.mark.parametrize(
    ("field", "value", "expected_reason"),
    [
        ("planned_investment_krw", 0, "MUST_BE_GREATER_THAN_ZERO"),
        ("monthly_income_krw", -1, "MUST_BE_NON_NEGATIVE"),
        ("annual_loan_rate", 1.01, "RATE_OUT_OF_RANGE"),
    ],
)
def test_invalid_input_uses_common_error_response(
    field: str,
    value: int | float,
    expected_reason: str,
) -> None:
    request = deepcopy(valid_request())
    request[field] = value

    # 투자금 합 불변식보다 테스트 대상 필드 검증이 먼저 실행되도록 필요한 값을 맞춘다.
    if field == "planned_investment_krw" and value == 0:
        request["equity_amount_krw"] = 0
        request["borrowed_amount_krw"] = 0

    with make_client() as client:
        response = client.post("/api/v1/financial-health/analyze", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["field_errors"] == [
        {"field": field, "reason": expected_reason}
    ]


def test_wrong_json_type_uses_common_error_response() -> None:
    request = valid_request()
    request["planned_investment_krw"] = "10000000"

    with make_client() as client:
        response = client.post("/api/v1/financial-health/analyze", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
