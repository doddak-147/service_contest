from datetime import date, timedelta
from decimal import Decimal

from app.integrations.stock_api.base import (
    Instrument,
    InstrumentNotFoundError,
    PricePoint,
    StockPriceAdapter,
)

FAKE_INSTRUMENTS: list[Instrument] = [
    Instrument(symbol="005930", market="KRX", name="삼성전자", currency="KRW"),
    Instrument(symbol="000660", market="KRX", name="SK하이닉스", currency="KRW"),
    Instrument(symbol="035420", market="KRX", name="NAVER", currency="KRW"),
    Instrument(symbol="005380", market="KRX", name="현대차", currency="KRW"),
    Instrument(symbol="035720", market="KRX", name="카카오", currency="KRW"),
    Instrument(symbol="373220", market="KRX", name="LG에너지솔루션", currency="KRW"),
    Instrument(symbol="GROWTH", market="KRX", name="테스트상승주", currency="KRW"),
    Instrument(symbol="CRASH", market="KRX", name="테스트폭락주", currency="KRW"),
    Instrument(symbol="RECOVER", market="KRX", name="테스트회복주", currency="KRW"),
    Instrument(symbol="NODATA", market="KRX", name="테스트부족주", currency="KRW"),
]


class FakeStockPriceAdapter(StockPriceAdapter):
    def __init__(
        self,
        instruments: list[Instrument] | None = None,
        custom_fixtures: dict[str, list[PricePoint]] | None = None,
    ) -> None:
        self._instruments = list(instruments or FAKE_INSTRUMENTS)
        self._custom_fixtures = custom_fixtures or {}

    async def search_instruments(self, query: str) -> list[Instrument]:
        normalized = query.strip().upper()
        if not normalized:
            return []
        return [
            inst
            for inst in self._instruments
            if normalized in inst.name.upper()
            or normalized in inst.symbol.upper()
        ]

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        matched = next(
            (
                inst
                for inst in self._instruments
                if inst.market.upper() == market.upper()
                and inst.symbol.upper() == symbol.upper()
            ),
            None,
        )
        if matched is None:
            raise InstrumentNotFoundError(market, symbol)

        if symbol in self._custom_fixtures:
            points = [
                pt
                for pt in self._custom_fixtures[symbol]
                if start_date <= pt.date <= end_date
            ]
            return "fake_provider", matched, points

        points = self._generate_fixture_points(
            symbol, start_date, end_date
        )
        return "fake_provider", matched, points

    def _generate_fixture_points(
        self, symbol: str, start_date: date, end_date: date
    ) -> list[PricePoint]:
        if symbol == "NODATA":
            return [PricePoint(date=start_date, adjusted_close=Decimal("50000"))]

        trading_days: list[date] = []
        cur = start_date
        while cur <= end_date:
            if cur.weekday() < 5:  # Monday to Friday
                trading_days.append(cur)
            cur += timedelta(days=1)

        if not trading_days:
            return []

        n = len(trading_days)
        points: list[PricePoint] = []

        if symbol == "GROWTH":
            # Strict monotonic increase: no drawdown
            base = Decimal("50000")
            for i, d in enumerate(trading_days):
                price = base + Decimal(i * 100)
                points.append(PricePoint(date=d, adjusted_close=price))
        elif symbol == "CRASH":
            # Sharp 40% drop and stays low without recovery
            base = Decimal("100000")
            for i, d in enumerate(trading_days):
                progress = i / max(n - 1, 1)
                if progress < 0.3:
                    price = base
                elif progress < 0.6:
                    price = base * Decimal("0.6")
                else:
                    price = base * Decimal("0.62")
                points.append(
                    PricePoint(
                        date=d, adjusted_close=Decimal(str(int(price)))
                    )
                )
        elif symbol == "RECOVER":
            # Drop from 100,000 to 65,000 then rise back to 105,000
            base = Decimal("100000")
            for i, d in enumerate(trading_days):
                progress = i / max(n - 1, 1)
                if progress < 0.2:
                    price = base + Decimal(i * 50)
                elif progress < 0.5:
                    # Drop
                    price = Decimal("65000") + Decimal(i * 30)
                else:
                    # Recover
                    price = Decimal("105000") + Decimal((i - n // 2) * 20)
                points.append(
                    PricePoint(
                        date=d, adjusted_close=Decimal(str(int(price)))
                    )
                )
        else:
            # Realistic synthetic wave for Samsung Electronics and others
            base = Decimal("70000") if symbol == "005930" else Decimal("120000")
            for i, d in enumerate(trading_days):
                cycle = Decimal(str(round(((i % 40) - 20) * 150, 2)))
                long_trend = Decimal(str(round((i - n / 2) * 30, 2)))
                price = base + cycle + long_trend
                if price <= Decimal("1000"):
                    price = Decimal("1000")
                points.append(
                    PricePoint(
                        date=d, adjusted_close=Decimal(str(int(price)))
                    )
                )

        return points
