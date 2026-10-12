import asyncio
from datetime import date
from decimal import Decimal

import httpx
import pytest

from app.integrations.stock_api.base import (
    InstrumentNotFoundError,
    MarketDataUnavailableError,
)
from app.integrations.stock_api.twelve import TwelveStockPriceAdapter


def test_search_keeps_only_us_stocks_and_caches_results() -> None:
    requests = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        assert request.url.path == "/symbol_search"
        assert request.url.params["symbol"] == "Apple"
        assert "apikey" not in request.url.params
        assert request.headers["Authorization"] == "apikey test-key"
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "data": [
                    {
                        "symbol": "AAPL",
                        "instrument_name": "Apple Inc.",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Common Stock",
                    },
                    {
                        "symbol": "AAPL",
                        "instrument_name": "Apple Inc.",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Common Stock",
                    },
                    {
                        "symbol": "005930",
                        "instrument_name": "Samsung Electronics",
                        "exchange": "KRX",
                        "country": "South Korea",
                        "currency": "KRW",
                        "instrument_type": "Common Stock",
                    },
                    {
                        "symbol": "SPY",
                        "instrument_name": "SPDR ETF",
                        "exchange": "NYSE",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "ETF",
                    },
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("test-key", client)
            first = await adapter.search_instruments("Apple")
            second = await adapter.search_instruments("apple")
            assert first == second
            assert [(item.symbol, item.market, item.currency) for item in first] == [
                ("AAPL", "NASDAQ", "USD")
            ]

    asyncio.run(run())
    assert requests == 1


def test_daily_split_adjusted_usd_closes_are_converted_with_date_matched_fx() -> None:
    requests = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        if request.url.host == "data-api.ecb.europa.eu":
            return httpx.Response(
                200,
                text=(
                    "CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\n"
                    "USD,2026-10-05,1.20,A\n"
                    "KRW,2026-10-05,1560,A\n"
                    "USD,2026-10-06,1.25,A\n"
                    "KRW,2026-10-06,1500,A\n"
                ),
            )
        if request.url.path == "/symbol_search":
            assert request.url.params["symbol"] == "AAPL"
            return httpx.Response(
                200,
                json={
                    "status": "ok",
                    "data": [
                        {
                            "symbol": "AAPL",
                            "instrument_name": "Apple Inc.",
                            "exchange": "NASDAQ",
                            "country": "United States",
                            "currency": "USD",
                            "instrument_type": "Common Stock",
                        }
                    ],
                },
            )
        assert request.url.path == "/time_series"
        assert request.url.params["interval"] == "1day"
        assert request.url.params["adjust"] == "splits"
        assert request.url.params["start_date"] == "2026-10-05"
        assert request.url.params["end_date"] == "2026-10-07T23:59:59"
        assert "apikey" not in request.url.params
        assert request.headers["Authorization"] == "apikey test-key"
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "meta": {
                    "symbol": "AAPL",
                    "exchange": "NASDAQ",
                    "currency": "USD",
                    "type": "Common Stock",
                },
                "values": [
                    {"datetime": "2026-10-07", "close": "120"},
                    {"datetime": "2026-10-06", "close": "110"},
                    {"datetime": "2026-10-05", "close": "100"},
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("test-key", client)
            source, instrument, points = await adapter.get_price_history(
                "NASDAQ", "aapl", date(2026, 10, 5), date(2026, 10, 7)
            )
            assert source == "twelve_data+ecb_reference_fx"
            assert instrument.name == "Apple Inc."
            assert [point.date for point in points] == [
                date(2026, 10, 5),
                date(2026, 10, 6),
                date(2026, 10, 7),
            ]
            assert [point.adjusted_close for point in points] == [
                Decimal("130000"),
                Decimal("132000"),
                Decimal("144000"),
            ]
            assert points[-1].fx_date == date(2026, 10, 6)
            assert (
                await adapter.get_price_history(
                    "NASDAQ", "AAPL", date(2026, 10, 5), date(2026, 10, 7)
                )
            )[2] == points

    asyncio.run(run())
    assert requests == 3


def test_unsupported_market_does_not_call_provider() -> None:
    async def run() -> None:
        adapter = TwelveStockPriceAdapter("test-key")
        with pytest.raises(InstrumentNotFoundError):
            await adapter.get_price_history(
                "KRX", "005930", date(2026, 10, 1), date(2026, 10, 7)
            )

    asyncio.run(run())


@pytest.mark.parametrize(
    "status,payload",
    [
        (429, {"status": "error", "message": "quota exceeded"}),
        (200, {"status": "error", "message": "invalid api key"}),
        (200, {"status": "ok", "data": None}),
    ],
)
def test_provider_failure_is_normalized_without_leaking_details(
    status: int, payload: dict[str, object]
) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(status, json=payload)

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            with pytest.raises(MarketDataUnavailableError) as error:
                await TwelveStockPriceAdapter("test-key", client).search_instruments(
                    "AAPL"
                )
            assert "test-key" not in str(error.value)
            assert "quota exceeded" not in str(error.value)

    asyncio.run(run())
