from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.features.stress_test.calculation import (
    FinancialProfile,
    ScenarioCalculation,
    ScenarioKey,
)


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)


class FinancialProfileInput(ContractModel):
    monthly_income_krw: int
    monthly_fixed_expenses_krw: int
    emergency_fund_krw: int
    existing_loan_balance_krw: int
    monthly_debt_payment_krw: int
    planned_investment_krw: int
    equity_amount_krw: int
    borrowed_amount_krw: int
    annual_loan_rate: float

    def to_domain(self) -> FinancialProfile:
        return FinancialProfile(
            monthly_income_krw=self.monthly_income_krw,
            monthly_fixed_expenses_krw=self.monthly_fixed_expenses_krw,
            emergency_fund_krw=self.emergency_fund_krw,
            existing_loan_balance_krw=self.existing_loan_balance_krw,
            monthly_debt_payment_krw=self.monthly_debt_payment_krw,
            planned_investment_krw=self.planned_investment_krw,
            equity_amount_krw=self.equity_amount_krw,
            borrowed_amount_krw=self.borrowed_amount_krw,
            annual_loan_rate=Decimal(str(self.annual_loan_rate)),
        )


class StressTestRequest(ContractModel):
    financial_profile: FinancialProfileInput
    historical_mdd_rate: float | None


class ScenarioResult(ContractModel):
    scenario_key: ScenarioKey
    label: str
    assumed_return_rate: float
    projected_investment_value_krw: int
    investment_pnl_krw: int
    investment_loss_krw: int
    reported_total_debt_krw: int
    net_investment_equity_krw: int
    loss_to_equity_ratio: float | None
    loss_to_emergency_fund_ratio: float | None
    loss_to_monthly_fixed_expenses: float | None
    estimated_annual_interest_krw: int
    estimated_monthly_interest_krw: int
    recovery_required_rate: float | None
    unavailable_reasons: list[str]

    @classmethod
    def from_calculation(cls, value: ScenarioCalculation) -> "ScenarioResult":
        return cls(
            scenario_key=value.scenario_key,
            label=value.label,
            assumed_return_rate=float(value.assumed_return_rate),
            projected_investment_value_krw=value.projected_investment_value_krw,
            investment_pnl_krw=value.investment_pnl_krw,
            investment_loss_krw=value.investment_loss_krw,
            reported_total_debt_krw=value.reported_total_debt_krw,
            net_investment_equity_krw=value.net_investment_equity_krw,
            loss_to_equity_ratio=(
                float(value.loss_to_equity_ratio)
                if value.loss_to_equity_ratio is not None
                else None
            ),
            loss_to_emergency_fund_ratio=(
                float(value.loss_to_emergency_fund_ratio)
                if value.loss_to_emergency_fund_ratio is not None
                else None
            ),
            loss_to_monthly_fixed_expenses=(
                float(value.loss_to_monthly_fixed_expenses)
                if value.loss_to_monthly_fixed_expenses is not None
                else None
            ),
            estimated_annual_interest_krw=value.estimated_annual_interest_krw,
            estimated_monthly_interest_krw=value.estimated_monthly_interest_krw,
            recovery_required_rate=(
                float(value.recovery_required_rate)
                if value.recovery_required_rate is not None
                else None
            ),
            unavailable_reasons=list(value.unavailable_reasons),
        )
