from fastapi import APIRouter

from app.features.financial_health.calculation import (
    FinancialHealthInputError,
    calculate_financial_health,
)
from app.features.financial_health.schemas import FinancialHealthResult
from app.features.stress_test.schemas import FinancialProfileInput
from app.shared.errors import ApiValidationError, FieldError

router = APIRouter(prefix="/api/v1/financial-health", tags=["financial-health"])


@router.post("/analyze", response_model=FinancialHealthResult)
def analyze_financial_health(
    request: FinancialProfileInput,
) -> FinancialHealthResult:
    """재무 원본을 저장하지 않고 요청 단위로 금융체력 결과만 계산한다."""

    try:
        calculation = calculate_financial_health(request.to_domain())
    except FinancialHealthInputError as exc:
        # 기존 Stress Test와 동일한 공통 VALIDATION_ERROR 형식을 유지한다.
        raise ApiValidationError(
            [FieldError(field=exc.field, reason=exc.reason)]
        ) from exc

    return FinancialHealthResult.from_calculation(calculation)
