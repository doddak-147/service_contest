import asyncio
from dataclasses import replace
from datetime import date, timedelta
from decimal import Decimal

import httpx
import pytest
from fastapi.testclient import TestClient

from app.features.market_risk.history import build_price_history
from app.features.market_risk.router import get_stock_adapter
from app.integrations.stock_api.base import (
    Instrument,
    MarketDataUnavailableError,
    PricePoint,
)
from app.integrations.stock_api.fake import FakeStockPriceAdapter
from app.integrations.stock_api.twelve import TwelveStockPriceAdapter
from app.main import create_app
from app.shared.config import Settings

START = date(2020, 1, 6)
INSTRUMENT = Instrument("QA", "NASDAQ", "Fictional QA", "USD")


def points() -> list[PricePoint]:
    return [
        PricePoint(
            START + timedelta(days=i),
            Decimal(krw),
            START + timedelta(days=i),
            Decimal(usd),
        )
        for i, (krw, usd) in enumerate(
            [(1000, 100), (1200, 120), (800, 100), (1320, 110)]
        )
    ]


def test_normalized_curves_and_mdd_dates_use_same_krw_series() -> None:
    result = build_price_history(
        INSTRUMENT, points(), START, START + timedelta(days=3), "synthetic_qa"
    )
    assert [p.krw_price_index for p in result.points] == [100, 120, 80, 132]
    assert [p.usd_price_index for p in result.points] == [100, 120, 100, 110]
    risk = result.market_risk
    assert risk.max_drawdown_rate == -0.333333
    assert (risk.peak_date, risk.trough_date, risk.recovery_date) == tuple(
        START + timedelta(days=i) for i in (1, 2, 3)
    )


@pytest.mark.parametrize("count", [0, 1])
def test_missing_quotes_do_not_create_a_curve(count: int) -> None:
    result = build_price_history(
        INSTRUMENT, points()[:count], START, START + timedelta(days=3), "synthetic_qa"
    )
    assert result.points == []
    assert "INSUFFICIENT_PRICE_DATA" in result.market_risk.warnings


def test_missing_usd_keeps_a_gap_without_inventing_fx_or_price() -> None:
    series = points()
    series[2] = replace(series[2], usd_adjusted_close=None)
    result = build_price_history(
        INSTRUMENT, series, START, series[-1].date, "synthetic_qa"
    )
    assert result.points[2].usd_price_index is None
    assert result.points[2].krw_price_index == 80
    assert "USD_PRICE_UNAVAILABLE" in result.market_risk.warnings


def test_zero_terminal_price_and_duplicate_dates() -> None:
    series = points()
    series[-1] = replace(
        series[-1], adjusted_close=Decimal(0), usd_adjusted_close=Decimal(0)
    )
    result = build_price_history(
        INSTRUMENT, series, START, series[-1].date, "synthetic_qa"
    )
    assert result.points[-1].krw_price_index == 0
    assert result.market_risk.max_drawdown_rate == -1
    with pytest.raises(MarketDataUnavailableError):
        build_price_history(
            INSTRUMENT, [series[0], series[0]], START, series[-1].date, "synthetic_qa"
        )


def test_history_endpoint_preserves_summary_contract_and_errors() -> None:
    app = create_app(Settings(app_env="test", cors_origins=()))
    app.dependency_overrides[get_stock_adapter] = lambda: FakeStockPriceAdapter(
        instruments=[INSTRUMENT],
        custom_fixtures={"QA": points()},
    )
    with TestClient(app) as client:
        suffix = "?start_date=2020-01-06&end_date=2020-01-09"
        summary = client.get("/api/v1/market-risk/NASDAQ/QA" + suffix)
        history = client.get("/api/v1/market-risk/NASDAQ/QA/history" + suffix)
        assert history.status_code == 200
        assert history.json()["market_risk"] == summary.json()
        assert history.json()["points"][0]["date"] == "2020-01-06"
        assert history.json()["points"][0]["fx_rate_as_of"] == "2020-01-06"
        assert (
            client.get(
                "/api/v1/market-risk/NASDAQ/UNKNOWN/history" + suffix
            ).status_code
            == 404
        )
        assert (
            client.get(
                "/api/v1/market-risk/NASDAQ/QA/history?start_date=2020-02-01&end_date=2020-01-01"
            ).status_code
            == 422
        )


def test_twelve_preserves_split_adjusted_usd_close_for_the_same_observations() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "data-api.ecb.europa.eu":
            return httpx.Response(
                200,
                text="CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\nUSD,2020-01-06,1,A\nKRW,2020-01-06,10,A\nUSD,2020-01-07,1,A\nKRW,2020-01-07,12,A\n",
            )
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "meta": {
                    "symbol": "QA",
                    "exchange": "NASDAQ",
                    "name": "QA",
                    "currency": "USD",
                    "type": "Common Stock",
                },
                "values": [
                    {"datetime": "2020-01-06", "close": "100"},
                    {"datetime": "2020-01-07", "close": "120"},
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            _, _, series = await TwelveStockPriceAdapter(
                "fictional-key", client
            ).get_price_history(
                "NASDAQ",
                "QA",
                START,
                START + timedelta(days=1),
            )
            assert [p.usd_adjusted_close for p in series] == [
                Decimal(100),
                Decimal(120),
            ]
            assert [p.adjusted_close for p in series] == [Decimal(1000), Decimal(1440)]

    asyncio.run(run())
