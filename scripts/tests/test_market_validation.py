import runpy
from dataclasses import replace
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

import pytest

MODULE = runpy.run_path(
    str(Path(__file__).resolve().parents[1] / "validate-market-data.py")
)


def test_independent_check_validates_dates_and_detects_wrong_mdd(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.integrations.stock_api.base import Instrument, PricePoint

    start = date(2020, 1, 1)
    expected = [
        (start + timedelta(days=i), Decimal(price), start + timedelta(days=i))
        for i, price in enumerate([100, 120, 90, 120])
    ]
    actual = [PricePoint(day, price, fx) for day, price, fx in expected]
    instrument = Instrument("QA", "NASDAQ", "Fictional QA", "USD")
    check = MODULE["verify_prices"]
    check(instrument, actual, expected, start, actual[-1].date, "synthetic_qa")
    original = check.__globals__["calculate_market_risk"]

    def wrong_result(*args, **kwargs):
        return replace(original(*args, **kwargs), max_drawdown_rate=Decimal("-0.1"))

    monkeypatch.setitem(check.__globals__, "calculate_market_risk", wrong_result)
    with pytest.raises(AssertionError):
        check(instrument, actual, expected, start, actual[-1].date, "synthetic_qa")


def test_independent_check_rejects_future_fx_and_wrong_price() -> None:
    from app.integrations.stock_api.base import Instrument, PricePoint

    start = date(2020, 1, 1)
    instrument = Instrument("QA", "NASDAQ", "Fictional QA", "USD")
    expected = [(start + timedelta(days=i), Decimal(100 + i), start) for i in range(3)]
    actual = [PricePoint(day, price, fx) for day, price, fx in expected]
    for altered in (
        replace(actual[1], fx_date=actual[1].date + timedelta(days=1)),
        replace(actual[1], adjusted_close=Decimal(999)),
    ):
        with pytest.raises(AssertionError):
            MODULE["verify_prices"](
                instrument,
                [actual[0], altered, actual[2]],
                expected,
                start,
                actual[-1].date,
                "synthetic_qa",
            )
