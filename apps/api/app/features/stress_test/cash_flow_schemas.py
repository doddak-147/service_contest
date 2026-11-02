from dataclasses import asdict
from decimal import Decimal
from typing import Literal

from app.features.stress_test.cash_flow import CashFlowAssumptions, CashFlowCalculation
from app.features.stress_test.schemas import (
    ContractModel,
    FinancialProfileInput,
    ScenarioResult,
)


class CashFlowRequest(ContractModel):
    financial_profile: FinancialProfileInput
    months: int = 6
    loan_term_months: int = 36
    repayment_method: Literal["interest_only", "equal_principal"] = "interest_only"
    income_change_rate: float = 0.0
    expense_change_rate: float = 0.0
    loan_rate_change: float = 0.0
    price_change_rate: float = 0.0
    exchange_rate_change_rate: float = 0.0
    investment_currency: Literal["KRW", "USD"] = "KRW"

    def to_assumptions(self) -> CashFlowAssumptions:
        rates = {
            name: Decimal(str(getattr(self, name)))
            for name in (
                "income_change_rate",
                "expense_change_rate",
                "loan_rate_change",
                "price_change_rate",
                "exchange_rate_change_rate",
            )
        }
        return CashFlowAssumptions(
            months=self.months,
            loan_term_months=self.loan_term_months,
            repayment_method=self.repayment_method,
            investment_currency=self.investment_currency,
            **rates,
        )


class MonthlyCashFlowResult(ContractModel):
    month: int
    income_krw: int
    fixed_expenses_krw: int
    existing_debt_payment_krw: int
    investment_interest_krw: int
    investment_principal_payment_krw: int
    monthly_net_cash_krw: int
    cash_balance_krw: int
    cash_shortfall_krw: int
    investment_loan_balance_krw: int
    cumulative_interest_krw: int


class CashFlowPathResult(ContractModel):
    monthly_points: list[MonthlyCashFlowResult]
    total_interest_krw: int
    total_principal_paid_krw: int
    ending_cash_balance_krw: int
    ending_loan_balance_krw: int
    first_shortfall_month: int | None


class CashFlowResult(ContractModel):
    calculation_version: str = "cash-flow-1.0.0"
    months: int
    initial_cash_krw: int
    baseline: CashFlowPathResult
    shocked: CashFlowPathResult
    investment_effect: ScenarioResult
    assumptions: list[str]

    @classmethod
    def from_calculation(
        cls, request: CashFlowRequest, value: CashFlowCalculation
    ) -> "CashFlowResult":
        return cls(
            months=request.months,
            initial_cash_krw=request.financial_profile.emergency_fund_krw,
            baseline=CashFlowPathResult.model_validate(
                {
                    **asdict(value.baseline),
                    "monthly_points": [
                        asdict(point) for point in value.baseline.monthly_points
                    ],
                }
            ),
            shocked=CashFlowPathResult.model_validate(
                {
                    **asdict(value.shocked),
                    "monthly_points": [
                        asdict(point) for point in value.shocked.monthly_points
                    ],
                }
            ),
            investment_effect=ScenarioResult.from_calculation(value.investment_effect),
            assumptions=[
                "소득·고정지출·금리는 선택한 조건이 기간 내내 유지된다고 가정합니다.",
                "시작 현금은 투자자금과 별도로 남겨 둔 비상자금입니다.",
                "투자 평가손익은 현금에 합산하지 않습니다. 배당·매도 수입은 없습니다.",
                "기존 대출 월상환액은 고정합니다.",
                "투자용 원금은 선택한 방식으로 상환합니다.",
                "이자만 납부하는 방식도 선택한 만기에 투자용 원금을 전액 상환합니다.",
                "월별 이자·원금 현금지출은 원 단위 반올림 후 누적합니다.",
                "음수는 자금 부족분입니다.",
                "추가 차입·연체이자는 계산하지 않습니다.",
                "세금·수수료·상품별 조건을 제외합니다.",
                "가정에 따른 계산이며 투자 판단을 제공하지 않습니다.",
            ],
        )
