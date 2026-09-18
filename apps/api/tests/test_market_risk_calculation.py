from datetime import date
from decimal import Decimal

from app.features.market_risk.calculation import (
    calculate_market_risk,
)
from app.integrations.stock_api.base import Instrument, PricePoint


def make_instrument() -> Instrument:
    return Instrument(
        symbol="005930",
        market="KRX",
        name="삼성전자",
        currency="KRW",
    )


def test_market_risk_calculation_standard_series() -> None:
    instrument = make_instrument()
    points = [
        PricePoint(date=date(2024, 1, 1), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("12000")),
        PricePoint(date=date(2024, 1, 3), adjusted_close=Decimal("9000")),
        PricePoint(date=date(2024, 1, 4), adjusted_close=Decimal("8000")),
        PricePoint(date=date(2024, 1, 5), adjusted_close=Decimal("11000")),
    ]

    calc = calculate_market_risk(
        instrument=instrument,
        price_points=points,
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 5),
        data_source="test_source",
    )

    assert calc.observation_count == 5
    assert calc.period_start == date(2024, 1, 1)
    assert calc.period_end == date(2024, 1, 5)
    assert calc.data_as_of == date(2024, 1, 5)
    assert calc.data_source == "test_source"

    # Period return: (11000 / 10000) - 1 = +0.100000
    assert calc.period_return_rate == Decimal("0.100000")

    # Peak: 12000 on Jan 2, Trough: 8000 on Jan 4
    # MDD: (8000 - 12000) / 12000 = -4000 / 12000 = -0.333333
    assert calc.max_drawdown_rate == Decimal("-0.333333")
    assert calc.peak_date == date(2024, 1, 2)
    assert calc.trough_date == date(2024, 1, 4)
    # Price reached 11000 which is < 12000, so not recovered
    assert calc.recovery_date is None
    assert calc.annualized_volatility is not None
    assert calc.annualized_volatility > Decimal("0")
    assert calc.warnings == ()


def test_market_risk_calculation_with_full_recovery() -> None:
    instrument = make_instrument()
    points = [
        PricePoint(date=date(2024, 1, 1), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("12000")),
        PricePoint(date=date(2024, 1, 3), adjusted_close=Decimal("7200")),
        PricePoint(date=date(2024, 1, 4), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 5), adjusted_close=Decimal("12500")),
    ]

    calc = calculate_market_risk(
        instrument=instrument,
        price_points=points,
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 5),
        data_source="test_source",
    )

    # MDD: (7200 - 12000) / 12000 = -0.400000
    assert calc.max_drawdown_rate == Decimal("-0.400000")
    assert calc.peak_date == date(2024, 1, 2)
    assert calc.trough_date == date(2024, 1, 3)
    # Recovered on Jan 5 when price reached 12500 >= 12000
    assert calc.recovery_date == date(2024, 1, 5)


def test_market_risk_calculation_monotonic_increase() -> None:
    instrument = make_instrument()
    points = [
        PricePoint(date=date(2024, 1, 1), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("11000")),
        PricePoint(date=date(2024, 1, 3), adjusted_close=Decimal("12000")),
    ]

    calc = calculate_market_risk(
        instrument=instrument,
        price_points=points,
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 3),
        data_source="test_source",
    )

    assert calc.max_drawdown_rate == Decimal("0.000000")
    assert calc.peak_date is None
    assert calc.trough_date is None
    assert calc.recovery_date is None
    assert calc.period_return_rate == Decimal("0.200000")


def test_market_risk_calculation_insufficient_points() -> None:
    instrument = make_instrument()
    calc_zero = calculate_market_risk(
        instrument=instrument,
        price_points=[],
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 5),
        data_source="test_source",
    )
    assert calc_zero.observation_count == 0
    assert calc_zero.period_return_rate is None
    assert calc_zero.annualized_volatility is None
    assert calc_zero.max_drawdown_rate is None
    assert "INSUFFICIENT_PRICE_DATA" in calc_zero.warnings

    calc_one = calculate_market_risk(
        instrument=instrument,
        price_points=[
            PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("10000"))
        ],
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 5),
        data_source="test_source",
    )
    assert calc_one.observation_count == 1
    assert calc_one.period_return_rate is None
    assert "INSUFFICIENT_PRICE_DATA" in calc_one.warnings


def test_market_risk_calculation_two_points() -> None:
    instrument = make_instrument()
    points = [
        PricePoint(date=date(2024, 1, 1), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("8000")),
    ]
    calc = calculate_market_risk(
        instrument=instrument,
        price_points=points,
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 2),
        data_source="test_source",
    )
    assert calc.observation_count == 2
    assert calc.period_return_rate == Decimal("-0.200000")
    assert calc.max_drawdown_rate == Decimal("-0.200000")
    # Only 1 daily return -> cannot calculate sample standard deviation (m < 2)
    assert calc.annualized_volatility is None
    assert calc.warnings == ("INSUFFICIENT_PRICE_DATA",)


def test_market_risk_calculation_total_loss() -> None:
    instrument = make_instrument()
    points = [
        PricePoint(date=date(2024, 1, 1), adjusted_close=Decimal("10000")),
        PricePoint(date=date(2024, 1, 2), adjusted_close=Decimal("5000")),
        PricePoint(date=date(2024, 1, 3), adjusted_close=Decimal("0")),
    ]
    calc = calculate_market_risk(
        instrument=instrument,
        price_points=points,
        requested_start_date=date(2024, 1, 1),
        requested_end_date=date(2024, 1, 3),
        data_source="test_source",
    )
    assert calc.period_return_rate == Decimal("-1.000000")
    assert calc.max_drawdown_rate == Decimal("-1.000000")
    assert calc.peak_date == date(2024, 1, 1)
    assert calc.trough_date == date(2024, 1, 3)
    assert calc.recovery_date is None


def test_split_adjusted_fixture_does_not_create_false_drawdown() -> None:
    """Samsung's 2018 50:1 split window stays on one adjusted price basis."""
    points = [
        PricePoint(date=date(2018, 4, 30), adjusted_close=Decimal("53000")),
        PricePoint(date=date(2018, 5, 2), adjusted_close=Decimal("53000")),
        PricePoint(date=date(2018, 5, 4), adjusted_close=Decimal("51900")),
        PricePoint(date=date(2018, 5, 8), adjusted_close=Decimal("52600")),
    ]

    calc = calculate_market_risk(
        instrument=make_instrument(),
        price_points=points,
        requested_start_date=date(2018, 4, 30),
        requested_end_date=date(2018, 5, 8),
        data_source="split_adjusted_fixture",
    )

    assert calc.observation_count == 4
    assert calc.period_return_rate == Decimal("-0.007547")
    assert calc.max_drawdown_rate == Decimal("-0.020755")
    assert calc.peak_date == date(2018, 4, 30)
    assert calc.trough_date == date(2018, 5, 4)
