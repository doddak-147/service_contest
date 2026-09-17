from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from app.integrations.stock_api.base import Instrument, PricePoint

RATIO_QUANTUM = Decimal("0.000001")


def _round_ratio(value: Decimal) -> Decimal:
    return value.quantize(RATIO_QUANTUM, rounding=ROUND_HALF_UP)


@dataclass(frozen=True, slots=True)
class MarketRiskCalculation:
    instrument: Instrument
    period_start: date
    period_end: date
    data_as_of: date
    data_source: str
    observation_count: int
    period_return_rate: Decimal | None
    annualized_volatility: Decimal | None
    max_drawdown_rate: Decimal | None
    peak_date: date | None
    trough_date: date | None
    recovery_date: date | None
    warnings: tuple[str, ...]


def calculate_market_risk(
    instrument: Instrument,
    price_points: list[PricePoint],
    requested_start_date: date,
    requested_end_date: date,
    data_source: str,
) -> MarketRiskCalculation:
    """Calculate period return, annualized volatility, and MDD from price points.

    Pure deterministic function without any I/O.
    """
    sorted_points = sorted(
        [
            pt
            for pt in price_points
            if requested_start_date <= pt.date <= requested_end_date
        ],
        key=lambda pt: pt.date,
    )

    n = len(sorted_points)

    if n < 2:
        last_date = sorted_points[-1].date if n == 1 else requested_end_date
        first_date = sorted_points[0].date if n == 1 else requested_start_date
        return MarketRiskCalculation(
            instrument=instrument,
            period_start=first_date,
            period_end=last_date,
            data_as_of=last_date,
            data_source=data_source,
            observation_count=n,
            period_return_rate=None,
            annualized_volatility=None,
            max_drawdown_rate=None,
            peak_date=None,
            trough_date=None,
            recovery_date=None,
            warnings=("INSUFFICIENT_PRICE_DATA",),
        )

    first_pt = sorted_points[0]
    last_pt = sorted_points[-1]
    period_start = first_pt.date
    period_end = last_pt.date
    data_as_of = last_pt.date
    observation_count = n
    warnings: list[str] = []

    # 1. Period return rate
    if first_pt.adjusted_close <= Decimal("0"):
        period_return_rate: Decimal | None = None
        warnings.append("INSUFFICIENT_PRICE_DATA")
    else:
        raw_return = (last_pt.adjusted_close / first_pt.adjusted_close) - Decimal("1")
        period_return_rate = _round_ratio(raw_return)

    # 2. Daily returns and Annualized volatility
    daily_returns: list[Decimal] = []
    for i in range(1, n):
        prev_close = sorted_points[i - 1].adjusted_close
        curr_close = sorted_points[i].adjusted_close
        if prev_close > Decimal("0"):
            ret = (curr_close / prev_close) - Decimal("1")
            daily_returns.append(ret)

    m = len(daily_returns)
    if m < 2:
        annualized_volatility: Decimal | None = None
        if "INSUFFICIENT_PRICE_DATA" not in warnings:
            warnings.append("INSUFFICIENT_PRICE_DATA")
    else:
        mean_ret = sum(daily_returns) / Decimal(m)
        sum_sq_diff = sum((r - mean_ret) ** 2 for r in daily_returns)
        sample_variance = sum_sq_diff / Decimal(m - 1)
        raw_vol = (sample_variance * Decimal("252")).sqrt()
        annualized_volatility = _round_ratio(raw_vol)

    # 3. Maximum Drawdown (MDD) and Peak/Trough/Recovery dates
    # Running peak
    running_peak = sorted_points[0].adjusted_close
    running_peak_idx = 0

    drawdowns: list[tuple[Decimal, int, int]] = []  # (drawdown, peak_idx, trough_idx)

    for i in range(n):
        curr_price = sorted_points[i].adjusted_close
        if curr_price > running_peak:
            running_peak = curr_price
            running_peak_idx = i

        if running_peak > Decimal("0"):
            dd = (curr_price - running_peak) / running_peak
        else:
            dd = Decimal("0")

        drawdowns.append((dd, running_peak_idx, i))

    min_dd, peak_idx, trough_idx = min(drawdowns, key=lambda x: x[0])

    if min_dd >= Decimal("0"):
        # Monotonically increasing or constant; no drawdown
        max_drawdown_rate = Decimal("0.000000")
        peak_date: date | None = None
        trough_date: date | None = None
        recovery_date: date | None = None
    else:
        max_drawdown_rate = _round_ratio(min_dd)
        peak_date = sorted_points[peak_idx].date
        trough_date = sorted_points[trough_idx].date

        peak_price = sorted_points[peak_idx].adjusted_close
        # Check if price recovered after trough
        recovery_date = None
        for j in range(trough_idx + 1, n):
            if sorted_points[j].adjusted_close >= peak_price:
                recovery_date = sorted_points[j].date
                break

    return MarketRiskCalculation(
        instrument=instrument,
        period_start=period_start,
        period_end=period_end,
        data_as_of=data_as_of,
        data_source=data_source,
        observation_count=observation_count,
        period_return_rate=period_return_rate,
        annualized_volatility=annualized_volatility,
        max_drawdown_rate=max_drawdown_rate,
        peak_date=peak_date,
        trough_date=trough_date,
        recovery_date=recovery_date,
        warnings=tuple(warnings),
    )
