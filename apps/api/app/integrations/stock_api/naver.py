from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import quote

import httpx

from app.integrations.stock_api.base import (
    Instrument,
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)
from app.integrations.stock_api.ecb_fx import EcbFxAdapter

SEARCH_URL = "https://ac.stock.naver.com/ac"
PRICE_URL = "https://fchart.stock.naver.com/sise.nhn"
SUPPORTED_MARKET = "KRX"
SUPPORTED_TYPE_CODES = frozenset({"KOSPI", "KOSDAQ", "KONEX"})
US_TYPE_CODES = frozenset({"NASDAQ", "NYSE", "AMEX"})
REUTERS_CODE = re.compile(r"^[A-Za-z0-9._-]{1,32}$")
US_CHART_URL = "https://api.stock.naver.com/chart/foreign/item/"


class NaverStockPriceAdapter(StockPriceAdapter):
    def __init__(
        self,
        client: httpx.AsyncClient | None = None,
        fx_adapter: EcbFxAdapter | None = None,
    ) -> None:
        self._client = client
        self._fx_adapter = fx_adapter or EcbFxAdapter(client)

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
        return [instrument for instrument, _ in await self._search_items(query)]

    async def _search_items(self, query: str) -> list[tuple[Instrument, str]]:
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

        instruments: list[tuple[Instrument, str]] = []
        seen: set[tuple[str, str]] = set()
        for item in raw_items:
            if not isinstance(item, dict):
                continue
            if item.get("category") != "stock":
                continue
            nation = item.get("nationCode")
            type_code = item.get("typeCode")
            if nation == "KOR" and type_code in SUPPORTED_TYPE_CODES:
                market, currency = SUPPORTED_MARKET, "KRW"
            elif nation == "USA" and type_code in US_TYPE_CODES:
                market, currency = type_code, "USD"
            else:
                continue

            symbol = item.get("code")
            name = item.get("name")
            reuters_code = item.get("reutersCode")
            if (
                not isinstance(symbol, str)
                or not isinstance(name, str)
                or not name.strip()
            ):
                continue
            if market == SUPPORTED_MARKET:
                if len(symbol) != 6 or not symbol.isdigit():
                    continue
                reuters_code = symbol
            elif (
                not re.fullmatch(r"[A-Za-z0-9.-]{1,20}", symbol)
                or not isinstance(reuters_code, str)
                or not REUTERS_CODE.fullmatch(reuters_code)
            ):
                continue

            key = (market, symbol)
            if key in seen:
                continue
            seen.add(key)
            instruments.append(
                (Instrument(
                    symbol=symbol,
                    market=market,
                    name=name.strip(),
                    currency=currency,
                ), reuters_code)
            )

        return instruments

    async def _resolve_instrument(
        self, market: str, symbol: str
    ) -> tuple[Instrument, str]:
        if market.upper() not in {SUPPORTED_MARKET, *US_TYPE_CODES}:
            raise InstrumentNotFoundError(market, symbol)

        matches = await self._search_items(symbol)
        matched = next(
            (
                item for item in matches
                if item[0].symbol.upper() == symbol.upper()
                and item[0].market == market.upper()
            ),
            None,
        )
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
        instrument, reuters_code = await self._resolve_instrument(market, symbol)
        if instrument.currency == "USD":
            return await self._get_us_price_history(
                instrument, reuters_code, start_date, end_date
            )

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

            points_by_date: dict[date, PricePoint] = {}
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
                    points_by_date[point_date] = PricePoint(
                        date=point_date,
                        adjusted_close=adjusted_close,
                    )
        except (ET.ParseError, InvalidOperation, ValueError) as exc:
            raise MarketDataUnavailableError() from exc

        # A provider retry can occasionally repeat a trading date. One close per
        # date prevents duplicate rows from distorting daily volatility.
        points = sorted(points_by_date.values(), key=lambda point: point.date)
        return "naver_finance", instrument, points

    async def _get_us_price_history(
        self,
        instrument: Instrument,
        reuters_code: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        response = await self._get(
            US_CHART_URL + quote(reuters_code, safe=""),
            params={"periodType": "dayCandle"},
        )
        try:
            payload: Any = response.json()
            raw_prices = payload["priceInfos"]
            if not isinstance(raw_prices, list):
                raise ValueError("Invalid US chart")
            usd_prices: dict[date, Decimal] = {}
            for row in raw_prices:
                day = date.fromisoformat(
                    f"{row['localDate'][:4]}-{row['localDate'][4:6]}-"
                    f"{row['localDate'][6:8]}"
                )
                close = Decimal(str(row["closePrice"]))
                if not close.is_finite() or close <= 0:
                    raise ValueError("Invalid US close")
                if start_date <= day <= end_date:
                    usd_prices[day] = close
        except (KeyError, ValueError, TypeError, InvalidOperation, IndexError) as exc:
            raise MarketDataUnavailableError() from exc

        if not usd_prices:
            return "naver_finance+ecb_reference_fx", instrument, []
        fx_rates = await self._fx_adapter.get_usd_krw(
            min(usd_prices), max(usd_prices)
        )
        ordered_fx = sorted(fx_rates)
        points: list[PricePoint] = []
        for day, usd_close in sorted(usd_prices.items()):
            fx_day = next((fx for fx in reversed(ordered_fx) if fx <= day), None)
            if fx_day is None or (day - fx_day).days > 5:
                continue
            points.append(
                PricePoint(
                    date=day,
                    adjusted_close=usd_close * fx_rates[fx_day],
                    fx_date=fx_day,
                )
            )
        return "naver_finance+ecb_reference_fx", instrument, points
