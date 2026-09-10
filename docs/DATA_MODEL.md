# 핵심 데이터 모델

## 1. 모델링 원칙

MVP의 모델은 데이터베이스 테이블이 아니라 FastAPI 요청·응답과 계산 함수에서 사용하는 비영속 모델이다. 재무 입력은 요청 처리 동안만 메모리에 존재하며 저장하거나 로그에 남기지 않는다.

- JSON 필드는 `snake_case`로 통일한다.
- 금액은 KRW 정수로 전송하고 Python 내부에서는 정수 또는 `Decimal`로 계산한다.
- 비율은 소수로 전송한다. 예: 20%는 `0.20`, 30% 하락은 `-0.30`이다.
- 날짜는 `YYYY-MM-DD`, 시각은 UTC ISO 8601 문자열을 사용한다.
- 계산할 수 없는 값은 0이 아니라 `null`과 사유 코드를 사용한다.
- 중간 계산은 반올림하지 않는다. API 직렬화 시 금액은 원 단위, 비율은 소수점 6자리 `ROUND_HALF_UP`을 적용한다.
- 정확한 wire type과 필드명은 [API_CONTRACT.md](./API_CONTRACT.md)가 단일 기준이다.

## 2. 입력 모델

### FinancialProfileInput

| 필드 | 타입 | 의미·규칙 |
|---|---|---|
| `monthly_income_krw` | integer | 월 소득, 0 이상 |
| `monthly_fixed_expenses_krw` | integer | 월 필수 고정지출, 0 이상 |
| `emergency_fund_krw` | integer | 즉시 사용할 수 있는 비상자금, 0 이상 |
| `existing_loan_balance_krw` | integer | 투자용 차입 전 기존 대출 잔액, 0 이상 |
| `monthly_debt_payment_krw` | integer | 기존 대출의 월 상환액, 0 이상 |
| `planned_investment_krw` | integer | 투자 예정금액, 0 초과 |
| `equity_amount_krw` | integer | 투자금 중 자기자본, 0 이상 |
| `borrowed_amount_krw` | integer | 투자금 중 차입금, 0 이상 |
| `annual_loan_rate` | number | 투자용 차입금의 명목 연이율, `0..1` |

불변식은 `equity_amount_krw + borrowed_amount_krw = planned_investment_krw`이다. 기존 대출의 금리는 MVP에서 입력받지 않으며 `monthly_debt_payment_krw`만 현금흐름에 반영한다.

### Instrument와 PricePoint

`Instrument`는 `symbol`, `market`, `name`, `currency`로 종목을 식별한다. 같은 심볼이 다른 시장에 존재할 수 있으므로 `(market, symbol)`을 한 쌍으로 사용한다.

`PricePoint`는 `date`, `adjusted_close`로 구성된 일별 조정종가다. 주가 어댑터 내부에서만 사용하며 외부 제공자의 필드명을 그대로 도메인에 노출하지 않는다.

## 3. 계산 결과 모델

### FinancialHealthResult

- `monthly_surplus_krw`: 소득 - 고정지출 - 기존 월 상환액
- `emergency_runway_months`: 비상자금 / (고정지출 + 기존 월 상환액)
- `leverage_ratio`: 투자용 차입금 / 투자 예정금액
- `estimated_monthly_interest_krw`: 투자용 차입금 × 연이율 / 12
- `reported_total_debt_krw`: 기존 대출 잔액 + 투자용 차입금
- `unavailable_reasons`: 0인 분모 등 계산 불가 사유 코드 배열

### MarketRiskResult

종목, 분석 기간, 데이터 제공자·기준일·관측치와 함께 `period_return_rate`, `annualized_volatility`, `max_drawdown_rate`를 가진다. `max_drawdown_rate`는 `-1..0` 범위의 음수다. MDD 구간은 `peak_date`, `trough_date`, `recovery_date`로 표현하며 미회복 상태의 `recovery_date`는 `null`이다.

### ScenarioResult

`scenario_key`는 `up_20`, `flat`, `down_10`, `down_20`, `down_30`, `down_40`, `down_50`, `historical_mdd` 중 하나다. 각 결과는 다음을 가진다.

- 가정: `label`, `assumed_return_rate`
- 자산·손익: `projected_investment_value_krw`, `investment_pnl_krw`, `investment_loss_krw`
- 부채·지분: `reported_total_debt_krw`, `net_investment_equity_krw`
- 충격: `loss_to_equity_ratio`, `loss_to_emergency_fund_ratio`, `loss_to_monthly_fixed_expenses`
- 부담·회복: `estimated_annual_interest_krw`, `estimated_monthly_interest_krw`, `recovery_required_rate`
- 예외: `unavailable_reasons`

`investment_pnl_krw`는 상승 시 양수, 하락 시 음수다. `investment_loss_krw`는 손실이 없으면 0인 비음수 값이다. 가격 충격만 적용하므로 부채 원금과 월 이자는 시나리오별로 변하지 않는다.

### CombinedAnalysisResult

개인 금융체력과 종목 과거 위험을 한 Report로 묶는다.

- 재현 정보: `request_id`, `calculated_at`, `calculation_version`
- 계산 결과: `financial_health`, `market_risk`, `mdd_impact`, `scenarios`
- 근거와 제한: `warnings`, `disclaimer`

`mdd_impact`는 종목의 `max_drawdown_rate`를 사용자의 투자금에 적용한 `ScenarioResult`다. 동일 값이 `scenarios`의 `historical_mdd` 항목에도 나타나야 한다.

## 4. AI 설명 모델

`ExplanationInput`은 결합 Report 전체가 아니라 선택한 결과의 최소 파생값만 가진다. 사용자 이름, 원본 소득, 원본 대출 목록, 비상자금 원금, 투자 의도는 포함하지 않는다.

허용 값은 시나리오 키·수익률, 이미 계산된 손실, 자기자본·비상자금·고정지출 대비 비율, 순투자지분, 월 이자, 종목 MDD, 경고 코드다. `ExplanationResult`는 설명 문자열과 `llm` 또는 `template` 출처만 가지며 금융 숫자의 권위 있는 저장소가 아니다.

## 5. 계산 불가 사유 코드

- `ZERO_EQUITY`: 자기자본이 0임
- `ZERO_EMERGENCY_FUND`: 비상자금이 0임
- `ZERO_FIXED_EXPENSES`: 고정지출이 0임
- `ZERO_ESSENTIAL_OUTFLOW`: 고정지출과 월 상환액 합이 0임
- `NO_FINITE_RECOVERY_RATE`: 100% 손실로 유한한 회복률이 없음
- `INSUFFICIENT_PRICE_DATA`: 주가 관측치가 부족함
- `MARKET_DATA_UNAVAILABLE`: 주가 API를 사용할 수 없음

## 6. MVP 이후 모델

3·6·12개월 누적 이자, 상환 방식, 계정과 저장 이력은 현재 모델에 미리 넣지 않는다. 해당 기능을 시작할 때 개인정보·보존 정책과 함께 별도 모델을 설계한다.
