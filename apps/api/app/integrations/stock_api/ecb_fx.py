"""ECB daily EUR reference-rate cross calculation (KRW per USD)."""

import csv
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
from io import StringIO
from time import monotonic
from typing import Any

import httpx

from app.integrations.stock_api.base import MarketDataUnavailableError

ECB_URL = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD+KRW.EUR.SP00.A"


class EcbFxAdapter:
    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client
        self._cache: dict[tuple[date, date], tuple[float, dict[date, Decimal]]] = {}

    async def get_usd_krw(
        self, start_date: date, end_date: date
    ) -> dict[date, Decimal]:
        key = (start_date, end_date)
        cached = self._cache.get(key)
        if cached is not None and monotonic() - cached[0] < 6 * 60 * 60:
            return cached[1]

        params = {
            "startPeriod": (start_date - timedelta(days=7)).isoformat(),
            "endPeriod": end_date.isoformat(),
            "format": "csvdata",
        }
        try:
            if self._client is not None:
                response = await self._client.get(ECB_URL, params=params, timeout=10.0)
            else:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(ECB_URL, params=params)
            response.raise_for_status()
            rows: Any = csv.DictReader(StringIO(response.text))
            values: dict[str, dict[date, Decimal]] = {"USD": {}, "KRW": {}}
            for row in rows:
                currency = row.get("CURRENCY")
                if currency not in values or row.get("OBS_STATUS") != "A":
                    continue
                day = date.fromisoformat(row["TIME_PERIOD"])
                value = Decimal(row["OBS_VALUE"])
                if not value.is_finite() or value <= 0:
                    raise ValueError("Invalid ECB reference rate")
                values[currency][day] = value
            rates = {
                day: krw_per_eur / values["USD"][day]
                for day, krw_per_eur in values["KRW"].items()
                if day in values["USD"]
            }
            if not rates:
                raise ValueError("No matching ECB reference rates")
        except (
            httpx.HTTPError,
            ValueError,
            KeyError,
            InvalidOperation,
            TypeError,
        ) as exc:
            raise MarketDataUnavailableError(
                "환율 데이터를 가져올 수 없습니다."
            ) from exc

        if len(self._cache) >= 32:
            self._cache.clear()
        self._cache[key] = (monotonic(), rates)
        return rates
