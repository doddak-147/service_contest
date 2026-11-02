from dataclasses import replace
from datetime import date
from decimal import ROUND_HALF_UP, Decimal
from math import isfinite

from app.features.market_risk.calculation import calculate_market_risk
from app.features.market_risk.schemas import (
    MarketPriceHistoryResult,
    MarketPricePoint,
    MarketRiskResult,
)
from app.integrations.stock_api.base import (
    Instrument,
    MarketDataUnavailableError,
    PricePoint,
)


def build_price_history(
    instrument: Instrument,
    points: list[PricePoint],
    start: date,
    end: date,
    source: str,
) -> MarketPriceHistoryResult:
    ordered = sorted(
        [point for point in points if start <= point.date <= end], key=lambda p: p.date
    )
    if len({point.date for point in ordered}) != len(ordered):
        raise MarketDataUnavailableError()
    if any(
        not p.adjusted_close.is_finite()
        or p.adjusted_close < 0
        or (
            p.usd_adjusted_close is not None
            and (not p.usd_adjusted_close.is_finite() or p.usd_adjusted_close < 0)
        )
        for p in ordered
    ):
        raise MarketDataUnavailableError()
    calc = calculate_market_risk(instrument, ordered, start, end, source)
    if len(ordered) < 2 or ordered[0].adjusted_close <= 0:
        return MarketPriceHistoryResult(
            market_risk=MarketRiskResult.from_calculation(calc), points=[]
        )
    usd_base = ordered[0].usd_adjusted_close
    usd_available = (
        instrument.currency == "USD" and usd_base is not None and usd_base > 0
    )
    if instrument.currency == "USD" and (
        not usd_available or any(p.usd_adjusted_close is None for p in ordered)
    ):
        calc = replace(calc, warnings=(*calc.warnings, "USD_PRICE_UNAVAILABLE"))

    def index(value: Decimal, base: Decimal) -> float:
        result = float(
            (value / base * 100).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
        )
        if not isfinite(result):
            raise MarketDataUnavailableError()
        return result

    return MarketPriceHistoryResult(
        market_risk=MarketRiskResult.from_calculation(calc),
        points=[
            MarketPricePoint(
                date=point.date,
                krw_price_index=index(point.adjusted_close, ordered[0].adjusted_close),
                usd_price_index=index(point.usd_adjusted_close, usd_base)
                if usd_available and point.usd_adjusted_close is not None
                else None,
                fx_rate_as_of=point.fx_date,
            )
            for point in ordered
        ],
    )
