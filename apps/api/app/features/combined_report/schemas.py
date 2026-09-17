from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, field_validator

from app.features.financial_health.schemas import FinancialHealthResult
from app.features.market_risk.schemas import Instrument, MarketRiskResult
from app.features.stress_test.schemas import FinancialProfileInput, ScenarioResult


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)


class CombinedAnalysisRequest(ContractModel):
    financial_profile: FinancialProfileInput
    instrument: Instrument
    period_start: date
    period_end: date

    @field_validator("period_start", "period_end", mode="before")
    @classmethod
    def parse_contract_date(cls, value: object) -> object:
        if isinstance(value, str):
            try:
                return date.fromisoformat(value)
            except ValueError:
                return value
        return value


class CombinedAnalysisResult(ContractModel):
    request_id: str
    calculated_at: datetime
    calculation_version: str
    financial_health: FinancialHealthResult
    market_risk: MarketRiskResult | None
    mdd_impact: ScenarioResult | None
    scenarios: list[ScenarioResult]
    warnings: list[str]
    disclaimer: str
