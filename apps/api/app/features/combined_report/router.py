from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.features.combined_report.schemas import (
    CombinedAnalysisRequest,
    CombinedAnalysisResult,
)
from app.features.financial_health.calculation import (
    FinancialHealthInputError,
    calculate_financial_health,
)
from app.features.financial_health.schemas import FinancialHealthResult
from app.features.market_risk.calculation import calculate_market_risk
from app.features.market_risk.router import get_stock_adapter
from app.features.market_risk.schemas import MarketRiskResult
from app.features.stress_test.calculation import (
    CalculationInputError,
    calculate_stress_tests,
)
from app.features.stress_test.schemas import ScenarioResult
from app.integrations.stock_api.base import (
    InstrumentNotFoundError,
    MarketDataUnavailableError,
    StockPriceAdapter,
)
from app.shared.errors import ApiValidationError, FieldError

router = APIRouter(prefix="/api/v1/combined-analyses", tags=["combined-report"])

CALCULATION_VERSION = "1.0.0"
DISCLAIMER = (
    "교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다. "
    "과거 성과는 미래 결과를 보장하지 않습니다."
)


def _append_warning(warnings: list[str], warning: str) -> None:
    if warning not in warnings:
        warnings.append(warning)


@router.post("", response_model=CombinedAnalysisResult)
async def create_combined_analysis(
    request: Request,
    payload: CombinedAnalysisRequest,
    adapter: Annotated[StockPriceAdapter, Depends(get_stock_adapter)],
) -> CombinedAnalysisResult:
    if payload.period_start > payload.period_end:
        raise ApiValidationError(
            [FieldError(field="period_start", reason="START_DATE_AFTER_END_DATE")]
        )

    profile = payload.financial_profile.to_domain()
    try:
        financial_calculation = calculate_financial_health(profile)
        scenario_calculations = calculate_stress_tests(profile, None)
    except (FinancialHealthInputError, CalculationInputError) as exc:
        raise ApiValidationError(
            [FieldError(field=exc.field, reason=exc.reason)]
        ) from exc

    warnings = list(financial_calculation.unavailable_reasons)
    market_result: MarketRiskResult | None = None
    mdd_impact: ScenarioResult | None = None

    try:
        data_source, instrument, price_points = await adapter.get_price_history(
            market=payload.instrument.market,
            symbol=payload.instrument.symbol,
            start_date=payload.period_start,
            end_date=payload.period_end,
        )
    except (InstrumentNotFoundError, MarketDataUnavailableError) as exc:
        _append_warning(warnings, exc.code)
    else:
        market_calculation = calculate_market_risk(
            instrument=instrument,
            price_points=price_points,
            requested_start_date=payload.period_start,
            requested_end_date=payload.period_end,
            data_source=data_source,
        )
        market_result = MarketRiskResult.from_calculation(market_calculation)
        for warning in market_calculation.warnings:
            _append_warning(warnings, warning)

        if market_calculation.max_drawdown_rate is not None:
            scenario_calculations = calculate_stress_tests(
                profile,
                Decimal(market_calculation.max_drawdown_rate),
            )
            mdd_impact = ScenarioResult.from_calculation(
                scenario_calculations[-1]
            )

    return CombinedAnalysisResult(
        request_id=str(request.state.request_id),
        calculated_at=datetime.now(UTC),
        calculation_version=CALCULATION_VERSION,
        financial_health=FinancialHealthResult.from_calculation(
            financial_calculation
        ),
        market_risk=market_result,
        mdd_impact=mdd_impact,
        scenarios=[
            ScenarioResult.from_calculation(value)
            for value in scenario_calculations
        ],
        warnings=warnings,
        disclaimer=DISCLAIMER,
    )
