"""Twelve Data Basic adapter for private U.S. stock and ETF demonstrations."""

import re
from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation
from time import monotonic
from typing import Any
from zoneinfo import ZoneInfo

import httpx

from app.integrations.stock_api.base import (
    Instrument,
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)
from app.integrations.stock_api.ecb_fx import EcbFxAdapter

API_BASE = "https://api.twelvedata.com"
US_MARKETS = frozenset({"NASDAQ", "NYSE", "AMEX"})
STOCK_TYPES = frozenset(
    {"Common Stock", "American Depositary Receipt", "Depositary Receipt"}
)
SUPPORTED_INSTRUMENT_TYPES = STOCK_TYPES | {"ETF"}
SYMBOL_PATTERN = re.compile(r"[A-Z][A-Z0-9.-]{0,19}")
US_EXCHANGE_TIMEZONE = ZoneInfo("America/New_York")
# Twelve Data provides English names and tickers. These aliases are intentionally
# limited to instruments we can identify unambiguously; the provider still
# verifies the actual instrument returned for each ticker.
KOREAN_INSTRUMENT_ALIASES = {
    "애플": "AAPL",
    "마이크로소프트": "MSFT",
    "마소": "MSFT",
    "엔비디아": "NVDA",
    "테슬라": "TSLA",
    "아마존": "AMZN",
    "메타": "META",
    "넷플릭스": "NFLX",
    "에스피와이": "SPY",
    "큐큐큐": "QQQ",
}


def _last_complete_us_date(now: datetime) -> date:
    if now.tzinfo is None:
        raise ValueError("A timezone-aware clock is required")
    # A daily candle can move during the U.S. trading day. Only include prior
    # exchange-local dates, allowing the close to settle overnight.
    return now.astimezone(US_EXCHANGE_TIMEZONE).date() - timedelta(days=1)


def _is_korean_query(query: str) -> bool:
    return any("\uac00" <= character <= "\ud7a3" for character in query)


def _korean_tickers(query: str) -> tuple[str, ...]:
    compact = "".join(query.split())
    if len(compact) < 2:
        return ()
    return tuple(
        dict.fromkeys(
            ticker
            for alias, ticker in KOREAN_INSTRUMENT_ALIASES.items()
            if alias.startswith(compact)
        )
    )


def _market(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    normalized = value.strip().upper()
    if normalized == "NYSE AMERICAN":
        return "AMEX"
    return normalized if normalized in US_MARKETS else None


def _instrument_from_search(item: object) -> Instrument | None:
    if not isinstance(item, dict):
        return None
    symbol = item.get("symbol")
    name = item.get("instrument_name")
    market = _market(item.get("exchange"))
    if (
        not isinstance(symbol, str)
        or not isinstance(name, str)
        or not name.strip()
        or market is None
        or item.get("country") not in {"United States", "US"}
        or item.get("currency") != "USD"
        or item.get("instrument_type") not in SUPPORTED_INSTRUMENT_TYPES
    ):
        return None
    normalized_symbol = symbol.strip().upper()
    if not SYMBOL_PATTERN.fullmatch(normalized_symbol):
        return None
    return Instrument(
        normalized_symbol,
        market,
        name.strip(),
        "USD",
        "etf" if item["instrument_type"] == "ETF" else "stock",
    )


class TwelveStockPriceAdapter(StockPriceAdapter):
    def __init__(
        self,
        api_key: str,
        client: httpx.AsyncClient | None = None,
        fx_adapter: EcbFxAdapter | None = None,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        if not api_key.strip():
            raise ValueError("TWELVE_DATA_API_KEY is required")
        self._api_key = api_key.strip()
        self._client = client
        self._fx_adapter = fx_adapter or EcbFxAdapter(client)
        self._clock = clock or (lambda: datetime.now(UTC))
        self._search_cache: dict[str, tuple[float, tuple[Instrument, ...]]] = {}
        self._history_cache: dict[
            tuple[str, str, date, date],
            tuple[float, tuple[str, Instrument, tuple[PricePoint, ...]]],
        ] = {}

    async def _get(self, path: str, params: dict[str, str]) -> dict[str, Any]:
        try:
            headers = {"Authorization": f"apikey {self._api_key}"}
            if self._client is not None:
                response = await self._client.get(
                    API_BASE + path, params=params, headers=headers, timeout=10.0
                )
            else:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(
                        API_BASE + path, params=params, headers=headers
                    )
            if response.status_code != 200:
                raise MarketDataUnavailableError()
            payload: Any = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise MarketDataUnavailableError() from exc
        if not isinstance(payload, dict) or payload.get("status") == "error":
            raise MarketDataUnavailableError()
        return payload

    async def search_instruments(self, query: str) -> list[Instrument]:
        normalized = query.strip()
        if not normalized:
            return []
        korean_query = _is_korean_query(normalized)
        cache_key = (
            "".join(normalized.split()) if korean_query else normalized.casefold()
        )
        cached = self._search_cache.get(cache_key)
        if cached is not None and monotonic() - cached[0] < 5 * 60:
            return list(cached[1])

        search_terms = _korean_tickers(normalized) if korean_query else (normalized,)
        results: list[Instrument] = []
        seen: set[tuple[str, str]] = set()
        for term in search_terms:
            payload = await self._get(
                "/symbol_search", {"symbol": term, "outputsize": "30"}
            )
            raw_items = payload.get("data")
            if not isinstance(raw_items, list):
                raise MarketDataUnavailableError()
            for item in raw_items:
                instrument = _instrument_from_search(item)
                if instrument is None or (korean_query and instrument.symbol != term):
                    continue
                key = (instrument.market, instrument.symbol)
                if key not in seen:
                    seen.add(key)
                    results.append(instrument)
        if len(self._search_cache) >= 64:
            self._search_cache.clear()
        self._search_cache[cache_key] = (monotonic(), tuple(results))
        return results

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        normalized_market = _market(market)
        normalized_symbol = symbol.strip().upper()
        if normalized_market is None or not SYMBOL_PATTERN.fullmatch(normalized_symbol):
            raise InstrumentNotFoundError(market, symbol)
        complete_end_date = min(end_date, _last_complete_us_date(self._clock()))
        cache_key = (
            normalized_market,
            normalized_symbol,
            start_date,
            complete_end_date,
        )
        cached = self._history_cache.get(cache_key)
        if cached is not None and monotonic() - cached[0] < 60 * 60:
            source, instrument, points = cached[1]
            return source, instrument, list(points)

        payload = await self._get(
            "/time_series",
            {
                "symbol": normalized_symbol,
                "exchange": normalized_market,
                "interval": "1day",
                "start_date": start_date.isoformat(),
                # A date-only end_date is midnight and excludes that day's daily candle.
                "end_date": (
                    f"{max(start_date, complete_end_date).isoformat()}T23:59:59"
                ),
                "adjust": "splits",
            },
        )
        meta = payload.get("meta")
        raw_values = payload.get("values")
        if not isinstance(meta, dict) or not isinstance(raw_values, list):
            raise MarketDataUnavailableError()
        actual_market = _market(meta.get("exchange"))
        actual_symbol = meta.get("symbol")
        if (
            actual_market != normalized_market
            or not isinstance(actual_symbol, str)
            or actual_symbol.upper() != normalized_symbol
            or meta.get("currency") != "USD"
            or (
                meta.get("type") is not None
                and meta["type"] not in SUPPORTED_INSTRUMENT_TYPES
            )
        ):
            raise MarketDataUnavailableError()
        name = meta.get("name")
        if not isinstance(name, str) or not name.strip():
            # The time_series metadata has no company name for many symbols.
            # Reuse a prior search when available; failure must not hide prices.
            try:
                matches = await self.search_instruments(normalized_symbol)
            except MarketDataUnavailableError:
                matches = []
            name = next(
                (
                    item.name
                    for item in matches
                    if item.symbol == normalized_symbol
                    and item.market == normalized_market
                ),
                normalized_symbol,
            )
        instrument = Instrument(
            symbol=normalized_symbol,
            market=normalized_market,
            name=name.strip()
            if isinstance(name, str) and name.strip()
            else normalized_symbol,
            currency="USD",
            instrument_type="etf" if meta.get("type") == "ETF" else "stock",
        )
        usd_prices: dict[date, Decimal] = {}
        try:
            for row in raw_values:
                if not isinstance(row, dict) or row.get("close") is None:
                    continue
                day = date.fromisoformat(row["datetime"])
                close = Decimal(str(row["close"]))
                if not close.is_finite() or close <= 0:
                    raise ValueError("Invalid close")
                if start_date <= day <= complete_end_date:
                    usd_prices[day] = close
        except (KeyError, TypeError, ValueError, InvalidOperation) as exc:
            raise MarketDataUnavailableError() from exc

        source = "twelve_data+ecb_reference_fx"
        if not usd_prices:
            result = (source, instrument, ())
        else:
            rates = await self._fx_adapter.get_usd_krw(min(usd_prices), max(usd_prices))
            ordered_fx = sorted(rates)
            points = []
            for day, usd_close in sorted(usd_prices.items()):
                fx_day = next((fx for fx in reversed(ordered_fx) if fx <= day), None)
                if fx_day is None or (day - fx_day).days > 5:
                    continue
                points.append(
                    PricePoint(day, usd_close * rates[fx_day], fx_date=fx_day)
                )
            result = (source, instrument, tuple(points))

        if len(self._history_cache) >= 64:
            self._history_cache.clear()
        self._history_cache[cache_key] = (monotonic(), result)
        return source, instrument, list(result[2])
