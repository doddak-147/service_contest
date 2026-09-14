from datetime import date

from pydantic import BaseModel, ConfigDict

from app.features.market_risk.calculation import MarketRiskCalculation
from app.integrations.stock_api.base import Instrument as DomainInstrument


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)


class Instrument(ContractModel):
    symbol: str
    market: str
    name: str
    currency: str

    @classmethod
    def from_domain(cls, domain: DomainInstrument) -> "Instrument":
        return cls(
            symbol=domain.symbol,
            market=domain.market,
            name=domain.name,
            currency=domain.currency,
        )

    def to_domain(self) -> DomainInstrument:
        return DomainInstrument(
            symbol=self.symbol,
            market=self.market,
            name=self.name,
            currency=self.currency,
        )


class MarketRiskResult(ContractModel):
    instrument: Instrument
    period_start: date
    period_end: date
    data_as_of: date
    data_source: str
    observation_count: int
    period_return_rate: float | None
    annualized_volatility: float | None
    max_drawdown_rate: float | None
    peak_date: date | None
    trough_date: date | None
    recovery_date: date | None
    warnings: list[str]

    @classmethod
    def from_calculation(cls, calc: MarketRiskCalculation) -> "MarketRiskResult":
        return cls(
            instrument=Instrument.from_domain(calc.instrument),
            period_start=calc.period_start,
            period_end=calc.period_end,
            data_as_of=calc.data_as_of,
            data_source=calc.data_source,
            observation_count=calc.observation_count,
            period_return_rate=(
                float(calc.period_return_rate)
                if calc.period_return_rate is not None
                else None
            ),
            annualized_volatility=(
                float(calc.annualized_volatility)
                if calc.annualized_volatility is not None
                else None
            ),
            max_drawdown_rate=(
                float(calc.max_drawdown_rate)
                if calc.max_drawdown_rate is not None
                else None
            ),
            peak_date=calc.peak_date,
            trough_date=calc.trough_date,
            recovery_date=calc.recovery_date,
            warnings=list(calc.warnings),
        )
