import asyncio
from datetime import date
from decimal import Decimal

import httpx
import pytest

from app.integrations.stock_api.base import MarketDataUnavailableError
from app.integrations.stock_api.ecb_fx import EcbFxAdapter


def test_ecb_cross_rate_uses_date_matched_eur_reference_rates() -> None:
    csv_body = (
        "CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\n"
        "USD,2026-10-08,1.25,A\n"
        "KRW,2026-10-08,1500,A\n"
        "USD,2026-10-09,1.20,A\n"
        "KRW,2026-10-09,1560,A\n"
    )

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "data-api.ecb.europa.eu"
        assert request.url.params["format"] == "csvdata"
        return httpx.Response(200, text=csv_body)

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = EcbFxAdapter(client)
            rates = await adapter.get_usd_krw(date(2026, 10, 8), date(2026, 10, 9))
            assert rates[date(2026, 10, 8)] == Decimal("1200")
            assert rates[date(2026, 10, 9)] == Decimal("1300")
            assert await adapter.get_usd_krw(
                date(2026, 10, 8), date(2026, 10, 9)
            ) is rates

    asyncio.run(run())


def test_ecb_empty_reference_rates_fail_without_leaking_provider_details() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="CURRENCY,TIME_PERIOD,OBS_VALUE,OBS_STATUS\n")

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            with pytest.raises(MarketDataUnavailableError):
                await EcbFxAdapter(client).get_usd_krw(
                    date(2026, 10, 8), date(2026, 10, 9)
                )

    asyncio.run(run())
