from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date
from decimal import Decimal


@dataclass(frozen=True, slots=True)
class Instrument:
    symbol: str
    market: str
    name: str
    currency: str


@dataclass(frozen=True, slots=True)
class PricePoint:
    date: date
    adjusted_close: Decimal


class StockDataError(Exception):
    """Base exception for stock data integration errors."""

    def __init__(self, message: str, code: str) -> None:
        super().__init__(message)
        self.code = code


class InstrumentNotFoundError(StockDataError):
    def __init__(self, market: str, symbol: str) -> None:
        super().__init__(
            f"종목을 찾을 수 없습니다: {market}/{symbol}",
            code="INSTRUMENT_NOT_FOUND",
        )
        self.market = market
        self.symbol = symbol


class MarketDataUnavailableError(StockDataError):
    def __init__(self, message: str = "주가 데이터를 가져올 수 없습니다.") -> None:
        super().__init__(message, code="MARKET_DATA_UNAVAILABLE")


class StockPriceAdapter(ABC):
    @abstractmethod
    async def search_instruments(self, query: str) -> list[Instrument]:
        """Search instruments matching the given query."""

    @abstractmethod
    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        """Fetch historical adjusted close prices.

        Returns (data_source_name, instrument, price_points).
        """
