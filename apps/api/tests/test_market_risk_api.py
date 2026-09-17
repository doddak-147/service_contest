from datetime import date

from fastapi.testclient import TestClient

from app.features.market_risk.router import get_stock_adapter
from app.integrations.stock_api.base import (
    Instrument,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)
from app.main import create_app
from app.shared.config import Settings

TEST_ORIGIN = "http://localhost:8081"


def make_client() -> TestClient:
    app = create_app(
        Settings(
            app_env="test",
            cors_origins=(TEST_ORIGIN,),
            stock_data_provider="fake",
        )
    )
    return TestClient(app)


def test_search_instruments_returns_matching_results() -> None:
    with make_client() as client:
        # Search by Korean name
        response = client.get("/api/v1/instruments/search?q=삼성")
        assert response.status_code == 200
        items = response.json()
        assert len(items) >= 1
        assert any(inst["name"] == "삼성전자" for inst in items)
        assert any(inst["symbol"] == "005930" for inst in items)
        assert all(inst["market"] == "KRX" for inst in items)
        assert all(inst["currency"] == "KRW" for inst in items)

        # Search by symbol
        response_symbol = client.get("/api/v1/instruments/search?q=000660")
        assert response_symbol.status_code == 200
        items_symbol = response_symbol.json()
        assert len(items_symbol) == 1
        assert items_symbol[0]["name"] == "SK하이닉스"


def test_search_instruments_empty_query_returns_validation_error() -> None:
    with make_client() as client:
        response = client.get("/api/v1/instruments/search?q=")
        assert response.status_code == 422
        body = response.json()
        assert body["error"]["code"] == "VALIDATION_ERROR"
        assert any(
            err["field"] == "q" and err["reason"] == "EMPTY_QUERY"
            for err in body["error"]["field_errors"]
        )

        response_whitespace = client.get("/api/v1/instruments/search?q=   ")
        assert response_whitespace.status_code == 422


def test_get_market_risk_success() -> None:
    with make_client() as client:
        response = client.get(
            "/api/v1/market-risk/KRX/005930?start_date=2024-01-01&end_date=2024-12-31"
        )
        assert response.status_code == 200
        result = response.json()
        assert result["instrument"]["symbol"] == "005930"
        assert result["instrument"]["market"] == "KRX"
        assert result["instrument"]["name"] == "삼성전자"
        assert result["instrument"]["currency"] == "KRW"
        assert result["period_start"] == "2024-01-01"
        assert result["period_end"] == "2024-12-31"
        assert result["data_source"] == "fake_provider"
        assert result["observation_count"] > 100
        assert result["period_return_rate"] is not None
        assert result["annualized_volatility"] is not None
        assert result["max_drawdown_rate"] is not None
        assert result["max_drawdown_rate"] <= 0.0
        assert result["warnings"] == []


def test_get_market_risk_not_found() -> None:
    with make_client() as client:
        response = client.get(
            "/api/v1/market-risk/KRX/NONEXISTENT"
            "?start_date=2024-01-01&end_date=2024-12-31"
        )
        assert response.status_code == 404
        body = response.json()
        assert body["error"]["code"] == "INSTRUMENT_NOT_FOUND"


def test_get_market_risk_start_after_end_date() -> None:
    with make_client() as client:
        response = client.get(
            "/api/v1/market-risk/KRX/005930?start_date=2024-12-31&end_date=2024-01-01"
        )
        assert response.status_code == 422
        body = response.json()
        assert body["error"]["code"] == "VALIDATION_ERROR"
        assert any(
            err["field"] == "start_date"
            and err["reason"] == "START_DATE_AFTER_END_DATE"
            for err in body["error"]["field_errors"]
        )


def test_get_market_risk_insufficient_data() -> None:
    with make_client() as client:
        response = client.get(
            "/api/v1/market-risk/KRX/NODATA?start_date=2024-01-01&end_date=2024-01-10"
        )
        assert response.status_code == 200
        result = response.json()
        assert result["observation_count"] == 1
        assert result["period_return_rate"] is None
        assert result["annualized_volatility"] is None
        assert result["max_drawdown_rate"] is None
        assert "INSUFFICIENT_PRICE_DATA" in result["warnings"]


def test_get_market_risk_with_recovery_fixture() -> None:
    with make_client() as client:
        response = client.get(
            "/api/v1/market-risk/KRX/RECOVER?start_date=2024-01-01&end_date=2024-06-30"
        )
        assert response.status_code == 200
        result = response.json()
        assert result["max_drawdown_rate"] is not None
        assert result["max_drawdown_rate"] < 0
        assert result["peak_date"] is not None
        assert result["trough_date"] is not None
        assert result["recovery_date"] is not None


class UnavailableStockPriceAdapter(StockPriceAdapter):
    async def search_instruments(self, query: str) -> list[Instrument]:
        raise MarketDataUnavailableError("internal-provider-detail")

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        raise MarketDataUnavailableError("internal-provider-detail")


def test_market_data_failure_uses_safe_common_error_response() -> None:
    app = create_app(
        Settings(
            app_env="test",
            cors_origins=(TEST_ORIGIN,),
            stock_data_provider="fake",
        )
    )
    app.dependency_overrides[get_stock_adapter] = UnavailableStockPriceAdapter

    with TestClient(app) as client:
        search_response = client.get("/api/v1/instruments/search?q=삼성")
        risk_response = client.get(
            "/api/v1/market-risk/KRX/005930?start_date=2024-01-01&end_date=2024-12-31"
        )

    for response in (search_response, risk_response):
        assert response.status_code == 503
        body = response.json()
        assert body["error"]["code"] == "MARKET_DATA_UNAVAILABLE"
        assert body["error"]["message"] == ("주가 데이터 제공자와 통신할 수 없습니다.")
        assert "internal-provider-detail" not in response.text
