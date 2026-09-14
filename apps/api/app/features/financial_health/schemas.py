from pydantic import BaseModel, ConfigDict

from app.features.financial_health.calculation import FinancialHealthCalculation


class ContractModel(BaseModel):
    """기존 Stress Test DTO와 동일하게 엄격한 API 계약을 적용한다."""

    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)


class FinancialHealthResult(ContractModel):
    monthly_surplus_krw: int
    emergency_runway_months: float | None
    leverage_ratio: float | None
    estimated_monthly_interest_krw: int
    reported_total_debt_krw: int
    unavailable_reasons: list[str]

    @classmethod
    def from_calculation(
        cls, value: FinancialHealthCalculation
    ) -> "FinancialHealthResult":
        """Decimal 계산 결과를 API wire type으로만 변환한다."""

        return cls(
            monthly_surplus_krw=value.monthly_surplus_krw,
            emergency_runway_months=(
                float(value.emergency_runway_months)
                if value.emergency_runway_months is not None
                else None
            ),
            leverage_ratio=(
                float(value.leverage_ratio)
                if value.leverage_ratio is not None
                else None
            ),
            estimated_monthly_interest_krw=value.estimated_monthly_interest_krw,
            reported_total_debt_krw=value.reported_total_debt_krw,
            unavailable_reasons=list(value.unavailable_reasons),
        )
