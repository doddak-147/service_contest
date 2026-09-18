import asyncio
from datetime import date

import httpx
import pytest

from app.integrations.stock_api.base import (
    InstrumentNotFoundError,
    MarketDataUnavailableError,
)
from app.integrations.stock_api.naver import NaverStockPriceAdapter


def autocomplete_response(items: list[dict[str, object]]) -> dict[str, object]:
    return {"query": "test", "items": items}


def stock_item(symbol: str = "001040", name: str = "CJ") -> dict[str, object]:
    return {
        "code": symbol,
        "name": name,
        "typeCode": "KOSPI",
        "nationCode": "KOR",
        "category": "stock",
    }


def test_search_instruments_uses_remote_results() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "ac.stock.naver.com"
        assert request.url.params["q"] == "001040"
        return httpx.Response(200, json=autocomplete_response([stock_item()]))

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            results = await NaverStockPriceAdapter(client).search_instruments("001040")

        assert len(results) == 1
        assert results[0].symbol == "001040"
        assert results[0].name == "CJ"
        assert results[0].market == "KRX"
        assert results[0].currency == "KRW"

    asyncio.run(run())


def test_get_price_history_resolves_name_and_parses_prices() -> None:
    xml = """<?xml version="1.0" encoding="EUC-KR" ?>
    <protocol><chartdata name="CJ">
      <item data="20240102|100|110|90|105|1000" />
      <item data="20240103|105|120|100|115|1200" />
    </chartdata></protocol>""".encode("euc-kr")

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "ac.stock.naver.com":
            return httpx.Response(200, json=autocomplete_response([stock_item()]))
        assert request.url.host == "fchart.stock.naver.com"
        assert request.url.params["symbol"] == "001040"
        return httpx.Response(200, content=xml)

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            source, instrument, points = await NaverStockPriceAdapter(
                client
            ).get_price_history(
                "KRX",
                "001040",
                date(2024, 1, 1),
                date(2024, 1, 31),
            )

        assert source == "naver_finance"
        assert instrument.name == "CJ"
        assert [point.adjusted_close for point in points] == [105, 115]

    asyncio.run(run())


def test_get_price_history_normalizes_duplicate_trading_dates() -> None:
    xml = """<?xml version="1.0" encoding="EUC-KR" ?>
    <protocol><chartdata name="CJ">
      <item data="20240102|100|110|90|105|1000" />
      <item data="20240102|100|115|90|108|1100" />
      <item data="20240103|108|120|100|115|1200" />
    </chartdata></protocol>""".encode("euc-kr")

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "ac.stock.naver.com":
            return httpx.Response(200, json=autocomplete_response([stock_item()]))
        return httpx.Response(200, content=xml)

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            _source, _instrument, points = await NaverStockPriceAdapter(
                client
            ).get_price_history(
                "KRX",
                "001040",
                date(2024, 1, 1),
                date(2024, 1, 31),
            )

        assert [point.date for point in points] == [
            date(2024, 1, 2),
            date(2024, 1, 3),
        ]
        assert [point.adjusted_close for point in points] == [108, 115]

    asyncio.run(run())


def test_get_price_history_rejects_unknown_symbol() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=autocomplete_response([]))

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            with pytest.raises(InstrumentNotFoundError):
                await NaverStockPriceAdapter(client).get_price_history(
                    "KRX",
                    "999999",
                    date(2024, 1, 1),
                    date(2024, 1, 31),
                )

    asyncio.run(run())


def test_search_instruments_hides_provider_error_details() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("internal-provider-host-detail")

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            with pytest.raises(MarketDataUnavailableError) as exc_info:
                await NaverStockPriceAdapter(client).search_instruments("삼성")

        assert "internal-provider-host-detail" not in str(exc_info.value)

    asyncio.run(run())
