from datetime import date

from app.integrations.stock_api.base import (
    Instrument,
    MarketDataUnavailableError,
    PricePoint,
    StockPriceAdapter,
)


class DisabledStockPriceAdapter(StockPriceAdapter):
    """Fail closed until an explicitly configured, licensed provider is ready."""

    async def search_instruments(self, query: str) -> list[Instrument]:
        raise MarketDataUnavailableError()

    async def get_price_history(
        self,
        market: str,
        symbol: str,
        start_date: date,
        end_date: date,
    ) -> tuple[str, Instrument, list[PricePoint]]:
        raise MarketDataUnavailableError()
