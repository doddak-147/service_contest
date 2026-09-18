from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

from app.features.financial_health.schemas import FinancialHealthResult
from app.features.market_risk.schemas import Instrument, MarketRiskResult
from app.features.stress_test.calculation import ScenarioKey
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


class ExplanationInput(ContractModel):
    scenario_key: ScenarioKey
    assumed_return_rate: float
    investment_loss_krw: int
    loss_to_equity_ratio: float | None
    loss_to_emergency_fund_ratio: float | None
    loss_to_monthly_fixed_expenses: float | None
    net_investment_equity_krw: int
    estimated_monthly_interest_krw: int
    market_max_drawdown_rate: float | None
    warnings: list[str]

    @model_validator(mode="after")
    def validate_calculated_values(self) -> "ExplanationInput":
        fixed_rates = {
            "up_20": 0.2,
            "flat": 0.0,
            "down_10": -0.1,
            "down_20": -0.2,
            "down_30": -0.3,
            "down_40": -0.4,
            "down_50": -0.5,
        }
        if self.scenario_key == "historical_mdd":
            if not -1 <= self.assumed_return_rate <= 0:
                raise ValueError("INVALID_SCENARIO_RATE")
            if self.market_max_drawdown_rate != self.assumed_return_rate:
                raise ValueError("MDD_SCENARIO_MISMATCH")
        elif self.assumed_return_rate != fixed_rates[self.scenario_key]:
            raise ValueError("INVALID_SCENARIO_RATE")

        if self.investment_loss_krw < 0:
            raise ValueError("NEGATIVE_INVESTMENT_LOSS")
        if self.estimated_monthly_interest_krw < 0:
            raise ValueError("NEGATIVE_MONTHLY_INTEREST")
        ratios = (
            self.loss_to_equity_ratio,
            self.loss_to_emergency_fund_ratio,
            self.loss_to_monthly_fixed_expenses,
        )
        if any(value is not None and value < 0 for value in ratios):
            raise ValueError("NEGATIVE_IMPACT_RATIO")
        if self.market_max_drawdown_rate is not None and not (
            -1 <= self.market_max_drawdown_rate <= 0
        ):
            raise ValueError("INVALID_MARKET_MDD")
        return self


class ExplanationResult(ContractModel):
    source: Literal["llm", "template"]
    summary: str
    caution: str
