from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Any

import httpx

from app.integrations.stock_api.base import (
    Instrument,
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)

SEARCH_URL = "https://ac.stock.naver.com/ac"
PRICE_URL = "https://fchart.stock.naver.com/sise.nhn"
SUPPORTED_MARKET = "KRX"
SUPPORTED_TYPE_CODES = frozenset({"KOSPI", "KOSDAQ", "KONEX"})


class NaverStockPriceAdapter(StockPriceAdapter):
    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def _get(
        self,
        url: str,
        *,
        params: dict[str, str | int],
    ) -> httpx.Response:
        try:
            if self._client is not None:
                response = await self._client.get(
                    url,
                    params=params,
                    timeout=8.0,
                )
            else:
                async with httpx.AsyncClient(timeout=8.0) as client:
                    response = await client.get(url, params=params)
        except httpx.HTTPError as exc:
            raise MarketDataUnavailableError() from exc

        if response.status_code != 200:
            raise MarketDataUnavailableError()
        return response

    async def search_instruments(self, query: str) -> list[Instrument]:
        normalized = query.strip()
        if not normalized:
            return []

        response = await self._get(
            SEARCH_URL,
            params={"q": normalized, "target": "stock"},
        )
        try:
            payload: Any = response.json()
        except ValueError as exc:
            raise MarketDataUnavailableError() from exc

        if not isinstance(payload, dict):
            raise MarketDataUnavailableError()
        raw_items = payload.get("items")
        if not isinstance(raw_items, list):
            raise MarketDataUnavailableError()

        instruments: list[Instrument] = []
        seen: set[tuple[str, str]] = set()
        for item in raw_items:
            if not isinstance(item, dict):
                continue
            if item.get("category") != "stock" or item.get("nationCode") != "KOR":
                continue
            if item.get("typeCode") not in SUPPORTED_TYPE_CODES:
                continue

            symbol = item.get("code")
            name = item.get("name")
            if (
                not isinstance(symbol, str)
                or len(symbol) != 6
                or not symbol.isdigit()
                or not isinstance(name, str)
                or not name.strip()
            ):
                continue

            key = (SUPPORTED_MARKET, symbol)
            if key in seen:
                continue
            seen.add(key)
            instruments.append(
                Instrument(
                    symbol=symbol,
                    market=SUPPORTED_MARKET,
                    name=name.strip(),
                    currency="KRW",
                )
            )

        return instruments

    async def _resolve_instrument(self, market: str, symbol: str) -> Instrument:
        if market.upper() != SUPPORTED_MARKET:
            raise InstrumentNotFoundError(market, symbol)

        matches = await self.search_instruments(symbol)
        matched = next((item for item in matches if item.symbol == symbol), None)
        if matched is None:
            raise InstrumentNotFoundError(market, symbol)
        return matched

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        instrument = await self._resolve_instrument(market, symbol)

        today = date.today()
        days_span = max((today - start_date).days + 60, 30)
        # Trading days are roughly 5/7 of calendar days.
        estimated_count = min(max(int(days_span * 0.75), 30), 4000)

        response = await self._get(
            PRICE_URL,
            params={
                "symbol": symbol,
                "timeframe": "day",
                "count": estimated_count,
                "requestType": 0,
            },
        )

        try:
            xml_text = response.content.decode("euc-kr")
        except UnicodeDecodeError:
            xml_text = response.content.decode("utf-8", errors="replace")

        try:
            root = ET.fromstring(xml_text)
            chartdata = root.find("chartdata")
            if chartdata is None:
                raise MarketDataUnavailableError()

            points: list[PricePoint] = []
            for item in chartdata.findall("item"):
                data_attr = item.get("data")
                if not data_attr:
                    continue
                parts = data_attr.split("|")
                if len(parts) < 5:
                    continue
                date_text = parts[0].strip()
                close_text = parts[4].strip()
                if len(date_text) != 8 or not date_text.isdigit():
                    continue

                point_date = date(
                    int(date_text[:4]),
                    int(date_text[4:6]),
                    int(date_text[6:8]),
                )
                if start_date <= point_date <= end_date:
                    adjusted_close = Decimal(close_text)
                    if not adjusted_close.is_finite() or adjusted_close < 0:
                        raise InvalidOperation
                    # This provider normalizes historical closes for stock splits.
                    points.append(
                        PricePoint(
                            date=point_date,
                            adjusted_close=adjusted_close,
                        )
                    )
        except (ET.ParseError, InvalidOperation, ValueError) as exc:
            raise MarketDataUnavailableError() from exc

        points.sort(key=lambda point: point.date)
        return "naver_finance", instrument, points
