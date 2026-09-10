from decimal import Decimal

from fastapi import APIRouter

from app.features.stress_test.calculation import (
    CalculationInputError,
    calculate_stress_tests,
)
from app.features.stress_test.schemas import ScenarioResult, StressTestRequest
from app.shared.errors import ApiValidationError, FieldError

router = APIRouter(prefix="/api/v1/stress-tests", tags=["stress-test"])


@router.post("/analyze", response_model=list[ScenarioResult])
def analyze_stress_tests(request: StressTestRequest) -> list[ScenarioResult]:
    historical_mdd_rate = (
        Decimal(str(request.historical_mdd_rate))
        if request.historical_mdd_rate is not None
        else None
    )
    try:
        calculations = calculate_stress_tests(
            request.financial_profile.to_domain(), historical_mdd_rate
        )
    except CalculationInputError as exc:
        raise ApiValidationError(
            [FieldError(field=exc.field, reason=exc.reason)]
        ) from exc

    return [ScenarioResult.from_calculation(value) for value in calculations]
