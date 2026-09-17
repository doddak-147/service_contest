from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request

from app.features.market_risk.calculation import calculate_market_risk
from app.features.market_risk.schemas import Instrument, MarketRiskResult
from app.integrations.stock_api.base import (
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    StockPriceAdapter,
)
from app.integrations.stock_api.fake import FakeStockPriceAdapter
from app.integrations.stock_api.naver import NaverStockPriceAdapter
from app.shared.errors import ApiValidationError, FieldError, _json_error

router = APIRouter(prefix="/api/v1", tags=["market-risk"])


def get_stock_adapter(request: Request) -> StockPriceAdapter:
    settings = getattr(request.app.state, "settings", None)
    provider = getattr(settings, "stock_data_provider", "fake") if settings else "fake"
    if provider == "naver":
        return NaverStockPriceAdapter()
    if provider == "fake":
        return FakeStockPriceAdapter()
    raise RuntimeError("Unsupported stock data provider configuration")


@router.get(
    "/instruments/search",
    response_model=list[Instrument],
)
async def search_instruments(
    request: Request,
    q: Annotated[str, Query(description="검색할 종목명 또는 종목코드")],
    adapter: Annotated[StockPriceAdapter, Depends(get_stock_adapter)],
) -> list[Instrument]:
    stripped = q.strip()
    if not stripped:
        raise ApiValidationError([FieldError(field="q", reason="EMPTY_QUERY")])

    try:
        results = await adapter.search_instruments(stripped)
    except MarketDataUnavailableError:
        return _json_error(
            request,
            status_code=503,
            code="MARKET_DATA_UNAVAILABLE",
            message="주가 데이터 제공자와 통신할 수 없습니다.",
        )  # type: ignore[return-value]
    return [Instrument.from_domain(inst) for inst in results]


@router.get(
    "/market-risk/{market}/{symbol}",
    response_model=MarketRiskResult,
)
async def get_market_risk(
    request: Request,
    market: str,
    symbol: str,
    start_date: Annotated[date, Query(description="조회 시작일 (YYYY-MM-DD)")],
    end_date: Annotated[date, Query(description="조회 종료일 (YYYY-MM-DD)")],
    adapter: Annotated[StockPriceAdapter, Depends(get_stock_adapter)],
) -> MarketRiskResult:
    if start_date > end_date:
        raise ApiValidationError(
            [
                FieldError(
                    field="start_date",
                    reason="START_DATE_AFTER_END_DATE",
                )
            ]
        )

    try:
        data_source, instrument, price_points = await adapter.get_price_history(
            market=market,
            symbol=symbol,
            start_date=start_date,
            end_date=end_date,
        )
    except InstrumentNotFoundError:
        return _json_error(
            request,
            status_code=404,
            code="INSTRUMENT_NOT_FOUND",
            message=f"해당 종목을 찾을 수 없습니다: {market}/{symbol}",
        )  # type: ignore[return-value]
    except MarketDataUnavailableError:
        return _json_error(
            request,
            status_code=503,
            code="MARKET_DATA_UNAVAILABLE",
            message="주가 데이터 제공자와 통신할 수 없습니다.",
        )  # type: ignore[return-value]

    calc = calculate_market_risk(
        instrument=instrument,
        price_points=price_points,
        requested_start_date=start_date,
        requested_end_date=end_date,
        data_source=data_source,
    )
    return MarketRiskResult.from_calculation(calc)
