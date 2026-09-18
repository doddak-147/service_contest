from typing import Any

from fastapi.testclient import TestClient

from app.features.combined_report.explanation_router import (
    get_explanation_adapter,
)
from app.integrations.llm.base import (
    ExplanationAdapter,
    ExplanationDraft,
    LlmUnavailableError,
)
from app.main import create_app
from app.shared.config import Settings


def valid_request() -> dict[str, Any]:
    return {
        "scenario_key": "historical_mdd",
        "assumed_return_rate": -0.3,
        "investment_loss_krw": 3_000_000,
        "loss_to_equity_ratio": 0.5,
        "loss_to_emergency_fund_ratio": 0.6,
        "loss_to_monthly_fixed_expenses": 2.0,
        "net_investment_equity_krw": 3_000_000,
        "estimated_monthly_interest_krw": 20_000,
        "market_max_drawdown_rate": -0.3,
        "warnings": [],
    }


def make_client(adapter: ExplanationAdapter | None = None) -> TestClient:
    app = create_app(Settings(app_env="test", cors_origins=()))
    if adapter is not None:
        app.dependency_overrides[get_explanation_adapter] = lambda: adapter
    return TestClient(app)


class CapturingAdapter(ExplanationAdapter):
    def __init__(self, summary: str) -> None:
        self.summary = summary
        self.payload: dict[str, object] | None = None

    async def generate(self, payload: dict[str, object]) -> ExplanationDraft:
        self.payload = payload
        return ExplanationDraft(summary=self.summary)


class UnavailableAdapter(ExplanationAdapter):
    async def generate(self, payload: dict[str, object]) -> ExplanationDraft:
        raise LlmUnavailableError


def test_template_provider_returns_approved_explanation() -> None:
    with make_client() as client:
        response = client.post("/api/v1/explanations", json=valid_request())

    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "template"
    assert "3,000,000원" in body["summary"]
    assert "50.0%" in body["summary"]
    assert "투자 추천" in body["caution"]


def test_llm_uses_only_minimal_result_and_server_substitutes_values() -> None:
    adapter = CapturingAdapter(
        "이 가정에서는 손실이 {{investment_loss_krw}}이고 자기자본 대비 "
        "{{loss_to_equity_ratio}}입니다."
    )
    with make_client(adapter) as client:
        response = client.post("/api/v1/explanations", json=valid_request())

    assert response.status_code == 200
    assert response.json()["source"] == "llm"
    assert "3,000,000원" in response.json()["summary"]
    assert "50.0%" in response.json()["summary"]
    assert adapter.payload == valid_request()
    assert "monthly_income_krw" not in adapter.payload
    assert "name" not in adapter.payload


def test_new_number_or_recommendation_falls_back_to_template() -> None:
    for unsafe_summary in (
        "손실은 4,000,000원입니다.",
        "손실은 십 퍼센트입니다. {{investment_loss_krw}}",
        "이 경우 매도를 추천합니다. {{investment_loss_krw}}",
        "알 수 없는 값은 {{monthly_income_krw}}입니다.",
    ):
        with make_client(CapturingAdapter(unsafe_summary)) as client:
            response = client.post(
                "/api/v1/explanations", json=valid_request()
            )

        assert response.status_code == 200
        assert response.json()["source"] == "template"
        assert "3,000,000원" in response.json()["summary"]


def test_llm_failure_keeps_template_result() -> None:
    with make_client(UnavailableAdapter()) as client:
        response = client.post("/api/v1/explanations", json=valid_request())

    assert response.status_code == 200
    assert response.json()["source"] == "template"


def test_explanation_contract_rejects_extra_financial_profile() -> None:
    request = valid_request()
    request["financial_profile"] = {"monthly_income_krw": 3_000_000}

    with make_client() as client:
        response = client.post("/api/v1/explanations", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_explanation_contract_rejects_impossible_calculated_value() -> None:
    request = valid_request()
    request["investment_loss_krw"] = -1

    with make_client() as client:
        response = client.post("/api/v1/explanations", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
