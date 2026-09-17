from datetime import date
from typing import Any

from fastapi.testclient import TestClient

from app.features.market_risk.router import get_stock_adapter
from app.integrations.stock_api.base import (
    Instrument,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)
from app.integrations.stock_api.fake import FakeStockPriceAdapter
from app.main import create_app
from app.shared.config import Settings

TEST_ORIGIN = "http://localhost:8081"


def make_client(adapter: StockPriceAdapter) -> TestClient:
    app = create_app(Settings(app_env="test", cors_origins=(TEST_ORIGIN,)))
    app.dependency_overrides[get_stock_adapter] = lambda: adapter
    return TestClient(app)


def valid_request(symbol: str = "005930", name: str = "삼성전자") -> dict[str, Any]:
    return {
        "financial_profile": {
            "monthly_income_krw": 3_000_000,
            "monthly_fixed_expenses_krw": 1_500_000,
            "emergency_fund_krw": 5_000_000,
            "existing_loan_balance_krw": 10_000_000,
            "monthly_debt_payment_krw": 400_000,
            "planned_investment_krw": 10_000_000,
            "equity_amount_krw": 6_000_000,
            "borrowed_amount_krw": 4_000_000,
            "annual_loan_rate": 0.06,
        },
        "instrument": {
            "symbol": symbol,
            "market": "KRX",
            "name": name,
            "currency": "KRW",
        },
        "period_start": "2025-01-01",
        "period_end": "2025-12-31",
    }


def test_combined_report_uses_same_market_mdd_for_impact_and_scenarios() -> None:
    with make_client(FakeStockPriceAdapter()) as client:
        response = client.post("/api/v1/combined-analyses", json=valid_request())

    assert response.status_code == 200
    body = response.json()
    assert body["request_id"] == response.headers["X-Request-ID"]
    assert body["calculation_version"] == "1.0.0"
    assert body["financial_health"]["monthly_surplus_krw"] == 1_100_000
    assert body["financial_health"]["reported_total_debt_krw"] == 14_000_000
    assert body["market_risk"]["instrument"]["symbol"] == "005930"
    assert body["mdd_impact"]["scenario_key"] == "historical_mdd"
    assert (
        body["mdd_impact"]["assumed_return_rate"]
        == body["market_risk"]["max_drawdown_rate"]
    )
    assert body["scenarios"][-1] == body["mdd_impact"]
    assert len(body["scenarios"]) == 8
    assert "투자 자문이 아닙니다" in body["disclaimer"]


class UnavailableStockPriceAdapter(StockPriceAdapter):
    async def search_instruments(self, query: str) -> list[Instrument]:
        return []

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        raise MarketDataUnavailableError()


def test_market_failure_returns_finance_and_fixed_scenarios() -> None:
    with make_client(UnavailableStockPriceAdapter()) as client:
        response = client.post("/api/v1/combined-analyses", json=valid_request())

    assert response.status_code == 200
    body = response.json()
    assert body["financial_health"]["monthly_surplus_krw"] == 1_100_000
    assert body["market_risk"] is None
    assert body["mdd_impact"] is None
    assert len(body["scenarios"]) == 7
    assert body["warnings"] == ["MARKET_DATA_UNAVAILABLE"]


def test_insufficient_prices_keep_market_metadata_without_mdd_impact() -> None:
    with make_client(FakeStockPriceAdapter()) as client:
        response = client.post(
            "/api/v1/combined-analyses",
            json=valid_request("NODATA", "테스트부족주"),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["market_risk"] is not None
    assert body["market_risk"]["max_drawdown_rate"] is None
    assert body["mdd_impact"] is None
    assert len(body["scenarios"]) == 7
    assert "INSUFFICIENT_PRICE_DATA" in body["warnings"]


def test_zero_equity_keeps_report_and_marks_ratio_unavailable() -> None:
    request = valid_request()
    request["financial_profile"]["equity_amount_krw"] = 0
    request["financial_profile"]["borrowed_amount_krw"] = 10_000_000

    with make_client(FakeStockPriceAdapter()) as client:
        response = client.post("/api/v1/combined-analyses", json=request)

    assert response.status_code == 200
    down_20 = next(
        result
        for result in response.json()["scenarios"]
        if result["scenario_key"] == "down_20"
    )
    assert down_20["loss_to_equity_ratio"] is None
    assert "ZERO_EQUITY" in down_20["unavailable_reasons"]


def test_start_date_after_end_date_uses_common_validation_error() -> None:
    request = valid_request()
    request["period_start"] = "2026-01-01"

    with make_client(FakeStockPriceAdapter()) as client:
        response = client.post("/api/v1/combined-analyses", json=request)

    assert response.status_code == 422
    assert response.json()["error"]["field_errors"] == [
        {"field": "period_start", "reason": "START_DATE_AFTER_END_DATE"}
    ]
