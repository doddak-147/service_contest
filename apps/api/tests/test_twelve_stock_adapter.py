import asyncio
from datetime import UTC, date, datetime
from decimal import Decimal

import httpx
import pytest

from app.integrations.stock_api.base import (
    InstrumentNotFoundError,
    MarketDataUnavailableError,
)
from app.integrations.stock_api.twelve import (
    TwelveStockPriceAdapter,
    _last_complete_us_date,
)


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
                        "symbol": "SPX",
                        "instrument_name": "S&P 500 Index",
                        "exchange": "NYSE",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Index",
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


@pytest.mark.parametrize("symbol,market", [("SPY", "NYSE"), ("QQQ", "NASDAQ")])
def test_us_etf_search_keeps_etfs_but_not_iex_or_indices(
    symbol: str, market: str
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/symbol_search"
        assert request.url.params["symbol"] == symbol
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "data": [
                    {
                        "symbol": symbol,
                        "instrument_name": f"{symbol} ETF",
                        "exchange": market,
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "ETF",
                    },
                    {
                        "symbol": symbol,
                        "instrument_name": f"{symbol} ETF",
                        "exchange": "IEX",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "ETF",
                    },
                    {
                        "symbol": f"{symbol}INDEX",
                        "instrument_name": "Index, not ETF",
                        "exchange": market,
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Index",
                    },
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("test-key", client)
            results = await adapter.search_instruments(symbol)
            assert [
                (item.symbol, item.market, item.instrument_type) for item in results
            ] == [(symbol, market, "etf")]

    asyncio.run(run())


def test_korean_etf_alias_search_uses_provider_verified_ticker() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["symbol"] == "QQQ"
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "data": [
                    {
                        "symbol": "QQQ",
                        "instrument_name": "Invesco QQQ Trust, Series 1",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "ETF",
                    }
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            results = await TwelveStockPriceAdapter(
                "test-key", client
            ).search_instruments("큐큐큐")
            assert [(item.symbol, item.instrument_type) for item in results] == [
                ("QQQ", "etf")
            ]

    asyncio.run(run())


def test_korean_stock_alias_search_uses_verified_ticker() -> None:
    requests = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        assert request.url.path == "/symbol_search"
        assert request.url.params["symbol"] == "MSFT"
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "data": [
                    {
                        "symbol": "MSFT",
                        "instrument_name": "Microsoft Corporation",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Common Stock",
                    },
                    {
                        "symbol": "MSFTX",
                        "instrument_name": "Another company",
                        "exchange": "NASDAQ",
                        "country": "United States",
                        "currency": "USD",
                        "instrument_type": "Common Stock",
                    },
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("test-key", client)
            first = await adapter.search_instruments("마이크로소프트")
            assert await adapter.search_instruments("마이크로 소프트") == first
            assert await adapter.search_instruments("모르는회사") == []
            assert await adapter.search_instruments("마") == []
            assert [(item.symbol, item.name) for item in first] == [
                ("MSFT", "Microsoft Corporation")
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
            adapter = TwelveStockPriceAdapter(
                "test-key",
                client,
                clock=lambda: datetime(2026, 10, 9, 12, tzinfo=UTC),
            )
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


@pytest.mark.parametrize("symbol,market", [("SPY", "NYSE"), ("QQQ", "NASDAQ")])
def test_etf_history_uses_same_krw_risk_series_and_preserves_type(
    symbol: str, market: str
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "data-api.ecb.europa.eu":
            return httpx.Response(
                200,
                text=(
                    "CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\n"
                    "USD,2026-10-05,1,A\n"
                    "KRW,2026-10-05,1300,A\n"
                    "USD,2026-10-06,1,A\n"
                    "KRW,2026-10-06,1300,A\n"
                ),
            )
        if request.url.path == "/symbol_search":
            return httpx.Response(
                200,
                json={
                    "status": "ok",
                    "data": [
                        {
                            "symbol": symbol,
                            "instrument_name": f"{symbol} ETF",
                            "exchange": market,
                            "country": "United States",
                            "currency": "USD",
                            "instrument_type": "ETF",
                        }
                    ],
                },
            )
        assert request.url.path == "/time_series"
        assert request.url.params["symbol"] == symbol
        assert request.url.params["exchange"] == market
        assert request.url.params["adjust"] == "splits"
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "meta": {
                    "symbol": symbol,
                    "exchange": market,
                    "currency": "USD",
                    "type": "ETF",
                },
                "values": [
                    {"datetime": "2026-10-06", "close": "90"},
                    {"datetime": "2026-10-05", "close": "100"},
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter(
                "test-key", client, clock=lambda: datetime(2026, 10, 9, 12, tzinfo=UTC)
            )
            source, instrument, points = await adapter.get_price_history(
                market, symbol, date(2026, 10, 5), date(2026, 10, 6)
            )
            assert source == "twelve_data+ecb_reference_fx"
            assert (
                instrument.symbol,
                instrument.market,
                instrument.instrument_type,
            ) == (
                symbol,
                market,
                "etf",
            )
            assert [point.adjusted_close for point in points] == [
                Decimal("130000"),
                Decimal("117000"),
            ]

    asyncio.run(run())


def test_current_us_day_is_excluded_until_next_new_york_day() -> None:
    now = [datetime(2026, 10, 26, 19, 15, tzinfo=UTC)]
    requested_ends: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "data-api.ecb.europa.eu":
            return httpx.Response(
                200,
                text=(
                    "CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\n"
                    "USD,2026-10-23,1,A\n"
                    "KRW,2026-10-23,1300,A\n"
                    "USD,2026-10-26,1,A\n"
                    "KRW,2026-10-26,1300,A\n"
                ),
            )
        assert request.url.path == "/time_series"
        requested_ends.append(request.url.params["end_date"])
        return httpx.Response(
            200,
            json={
                "status": "ok",
                "meta": {
                    "symbol": "AAPL",
                    "name": "Apple Inc.",
                    "exchange": "NASDAQ",
                    "currency": "USD",
                    "type": "Common Stock",
                },
                # Guard against a provider returning a row beyond its queried end.
                "values": [
                    {"datetime": "2026-10-26", "close": "110"},
                    {"datetime": "2026-10-23", "close": "100"},
                ],
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = TwelveStockPriceAdapter("test-key", client, clock=lambda: now[0])
            first = await adapter.get_price_history(
                "NASDAQ", "AAPL", date(2026, 10, 23), date(2026, 10, 27)
            )
            assert [point.date for point in first[2]] == [date(2026, 10, 23)]

            now[0] = datetime(2026, 10, 27, 4, 5, tzinfo=UTC)
            second = await adapter.get_price_history(
                "NASDAQ", "AAPL", date(2026, 10, 23), date(2026, 10, 27)
            )
            assert [point.date for point in second[2]] == [
                date(2026, 10, 23),
                date(2026, 10, 26),
            ]
            # The combined report's narrower request reuses the same stable
            # price series instead of fetching a different live close.
            assert (
                await adapter.get_price_history(
                    "NASDAQ", "AAPL", date(2026, 10, 23), date(2026, 10, 26)
                )
            )[2] == second[2]

    asyncio.run(run())
    assert requested_ends == [
        "2026-10-25T23:59:59",
        "2026-10-26T23:59:59",
    ]


def test_us_day_cutoff_uses_new_york_daylight_saving_time() -> None:
    assert _last_complete_us_date(datetime(2026, 12, 1, 4, 30, tzinfo=UTC)) == date(
        2026, 11, 29
    )
    assert _last_complete_us_date(datetime(2026, 12, 1, 5, 30, tzinfo=UTC)) == date(
        2026, 11, 30
    )


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
