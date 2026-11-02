import asyncio
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.features.combined_report.explanation_router import get_explanation_adapter
from app.integrations.llm.openai_compatible import OpenAICompatibleExplanationAdapter
from app.integrations.stock_api.base import MarketDataUnavailableError
from app.integrations.stock_api.twelve import TwelveStockPriceAdapter
from app.main import create_app
from app.shared.config import Settings


def fail_once(mode: str, request: httpx.Request) -> httpx.Response:
    if mode == "timeout":
        raise httpx.ReadTimeout("fictional provider failure", request=request)
    return httpx.Response(int(mode), json={"status": "error", "message": "unavailable"})


@pytest.mark.parametrize("mode", ["429", "500", "timeout"])
def test_twelve_failure_does_not_cache_or_prevent_retry(mode: str) -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return fail_once(mode, request)
        return httpx.Response(
            200,
            json={
                "data": [
                    {
                        "symbol": "AAPL",
                        "instrument_name": "QA stock",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Common Stock",
                    }
                ]
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("fictional-test-key", client)
            with pytest.raises(MarketDataUnavailableError):
                await adapter.search_instruments("AAPL")
            recovered = await adapter.search_instruments("AAPL")
            assert len(recovered) == 1
            assert recovered[0].symbol == "AAPL"
        assert calls == 2

    asyncio.run(run())


@pytest.mark.parametrize("mode", ["429", "500", "timeout"])
def test_llm_failure_returns_template_then_next_request_recovers(mode: str) -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return fail_once(mode, request)
        summary = json.dumps({"summary": "가정 손실은 {{investment_loss_krw}}입니다."})
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": summary}}]},
        )

    async def adapter_dependency():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            yield OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="fictional-test-key",
                model="test-model",
                client=client,
            )

    app = create_app(Settings(app_env="test", cors_origins=()))
    app.dependency_overrides[get_explanation_adapter] = adapter_dependency
    payload = {
        "scenario_key": "historical_mdd",
        "assumed_return_rate": -0.3,
        "investment_loss_krw": 3000000,
        "loss_to_equity_ratio": 0.5,
        "loss_to_emergency_fund_ratio": 0.6,
        "loss_to_monthly_fixed_expenses": 2,
        "net_investment_equity_krw": 3000000,
        "estimated_monthly_interest_krw": 20000,
        "market_max_drawdown_rate": -0.3,
        "warnings": [],
    }
    with TestClient(app) as client:
        first = client.post("/api/v1/explanations", json=payload)
        second = client.post("/api/v1/explanations", json=payload)
    assert first.status_code == second.status_code == 200
    assert first.json()["source"] == "template"
    assert first.json()["fallback_reason"] == "provider_unavailable"
    assert second.json()["source"] == "llm"
    assert "3,000,000원" in first.json()["summary"]
    assert "3,000,000원" in second.json()["summary"]
    assert calls == 2
