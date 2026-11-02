# MVP API Contract

## 1. 계약 원칙

이 문서는 모바일과 FastAPI 사이 요청·응답의 단일 기준이다. 구현자가 필드명, 타입, 단위, `null` 의미를 임의로 바꾸거나 같은 값을 다른 이름으로 추가하면 안 된다.

- Base path: `/api/v1`
- Content-Type: `application/json`
- JSON 이름: `snake_case`
- 금액: KRW 정수(`integer`)
- 비율: 소수(`number`), 예: `0.20`, 하락은 `-0.20`
- 날짜: `YYYY-MM-DD`; 시각: UTC ISO 8601
- nullable: `type | null`로 명시된 필드만 허용
- 변경 절차: 문서 → FastAPI schema → 모바일 타입 → unit/contract test를 한 PR에서 변경
- 반올림: 금액은 응답 직전 원 단위 `ROUND_HALF_UP`, 비율은 소수점 6자리 `ROUND_HALF_UP`; UI 표시용 반올림은 계산값을 변경하지 않음

현재 공모전 시연용 운영 Base URL은 `https://service-contest-2026-api.duckdns.org`이다. 로컬 주소와 운영 주소는 환경에 따라 달라지지만 아래 path와 JSON 계약은 동일하다. `/health`는 인프라 상태 확인용이므로 `/api/v1` 밖에 둔다.

## 2. 공통 타입

아래 표기가 권위 있는 wire type이다. `date`와 `datetime`은 위 형식의 JSON 문자열이다.

```text
FinancialProfileInput {
  monthly_income_krw: integer
  monthly_fixed_expenses_krw: integer
  emergency_fund_krw: integer
  existing_loan_balance_krw: integer
  monthly_debt_payment_krw: integer
  planned_investment_krw: integer
  equity_amount_krw: integer
  borrowed_amount_krw: integer
  annual_loan_rate: number
}

Instrument {
  symbol: string
  market: string
  name: string
  currency: string
  instrument_type?: "stock" | "etf"
}

FinancialHealthResult {
  monthly_surplus_krw: integer
  emergency_runway_months: number | null
  leverage_ratio: number | null
  estimated_monthly_interest_krw: integer
  reported_total_debt_krw: integer
  unavailable_reasons: string[]
}

MarketRiskResult {
  instrument: Instrument
  period_start: date
  period_end: date
  data_as_of: date
  fx_rate_as_of: date | null
  data_source: string
  observation_count: integer
  period_return_rate: number | null
  annualized_volatility: number | null
  max_drawdown_rate: number | null
  peak_date: date | null
  trough_date: date | null
  recovery_date: date | null
  warnings: string[]
}

ScenarioKey = up_20 | flat | down_10 | down_20 | down_30 | down_40 | down_50 | historical_mdd | custom

ScenarioResult {
  scenario_key: ScenarioKey
  label: string
  assumed_return_rate: number
  price_change_rate: number | null
  exchange_rate_change_rate: number | null
  projected_investment_value_krw: integer
  investment_pnl_krw: integer
  investment_loss_krw: integer
  reported_total_debt_krw: integer
  net_investment_equity_krw: integer
  loss_to_equity_ratio: number | null
  loss_to_emergency_fund_ratio: number | null
  loss_to_monthly_fixed_expenses: number | null
  estimated_annual_interest_krw: integer
  estimated_monthly_interest_krw: integer
  recovery_required_rate: number | null
  unavailable_reasons: string[]
}

CombinedAnalysisResult {
  request_id: string
  calculated_at: datetime
  calculation_version: string
  financial_health: FinancialHealthResult
  market_risk: MarketRiskResult | null
  mdd_impact: ScenarioResult | null
  scenarios: ScenarioResult[]
  warnings: string[]
  disclaimer: string
}

ExplanationInput {
  scenario_key: ScenarioKey
  assumed_return_rate: number
  investment_loss_krw: integer
  loss_to_equity_ratio: number | null
  loss_to_emergency_fund_ratio: number | null
  loss_to_monthly_fixed_expenses: number | null
  net_investment_equity_krw: integer
  estimated_monthly_interest_krw: integer
  market_max_drawdown_rate: number | null
  warnings: string[]
}

ExplanationResult {
  source: llm | template
  summary: string
  caution: string
}
```

### FinancialProfileInput

```json
{
  "monthly_income_krw": 3000000,
  "monthly_fixed_expenses_krw": 1500000,
  "emergency_fund_krw": 5000000,
  "existing_loan_balance_krw": 10000000,
  "monthly_debt_payment_krw": 400000,
  "planned_investment_krw": 10000000,
  "equity_amount_krw": 6000000,
  "borrowed_amount_krw": 4000000,
  "annual_loan_rate": 0.06
}
```

모든 금액은 0 이상이고 `planned_investment_krw`만 0보다 커야 한다. `annual_loan_rate`는 `0..1`이며 자기자본과 차입금 합은 투자 예정금액과 같아야 한다.

### Instrument

```json
{
  "symbol": "005930",
  "market": "KRX",
  "name": "삼성전자",
  "currency": "KRW",
  "instrument_type": "stock"
}
```

`instrument_type`은 미국 상장 주식과 ETF를 구분한다. 기존 요청에서 생략하면 `stock`으로 해석한다. 모바일은 구형 서버와의 호환을 위해 주식 요청에서 생략하고 ETF 요청에만 `etf`를 보낸다. 새 서버의 응답에는 항상 포함한다. ETF는 추종 지수 자체가 아니며 지수 성과와 일치한다고 가정하지 않는다.

### MarketRiskResult

```json
{
  "instrument": {
    "symbol": "005930",
    "market": "KRX",
    "name": "삼성전자",
    "currency": "KRW",
    "instrument_type": "stock"
  },
  "period_start": "2023-01-02",
  "period_end": "2025-12-30",
  "data_as_of": "2025-12-30",
  "fx_rate_as_of": null,
  "data_source": "provider_name",
  "observation_count": 735,
  "period_return_rate": 0.12,
  "annualized_volatility": 0.24,
  "max_drawdown_rate": -0.31,
  "peak_date": "2024-07-10",
  "trough_date": "2025-04-09",
  "recovery_date": null,
  "warnings": []
}
```

`period_return_rate`, `annualized_volatility`, `max_drawdown_rate`는 `number | null`이다. 분석 불가 값은 `null`로 두고 `warnings`에 사유 코드를 넣는다.

미국 상장 주식·ETF는 `market`이 `NASDAQ | NYSE | AMEX`, `currency`가 `USD`이며 앱에서 최근 3개월을 조회한다. Twelve Data Basic을 선택한 경우 검색과 과거 시세는 이 범위로 제한하고 지수 자체는 제외한다. 검색은 영어 이름·티커 외에 서버에 등록된 일부 한글 별칭도 받는다. 국내 `KRX` 시세는 제공하지 않는다. 서버는 분할 조정된 USD 일별 종가(`adjust=splits`, 배당 제외)에 ECB의 EUR 대비 KRW·USD 일별 기준 환율을 교차 계산한 원/달러 참고 환율을 곱해 원화 가격 시계열을 만든다. ETF도 같은 가격 기준으로 분석하므로 분배금 재투자 수익률이나 추종 지수 수익률로 해석하면 안 된다. 미국 거래소 현지 날짜의 당일 일봉은 마감 전 변동할 수 있으므로 제외하고 전날까지의 관측치만 분석한다. 기간 수익률·변동성·MDD는 이 원화 시계열 기준이다. `fx_rate_as_of`는 마지막 주가 관측에 적용한 환율 날짜이며 국내 종목은 `null`이다. 휴일에는 최대 5일 전 기준 환율을 사용하고, 그보다 오래된 환율만 있으면 해당 주가 관측을 제외한다. `data_source`는 Twelve Data 이용 시 `twelve_data+ecb_reference_fx`다. `PARTIAL_PRICE_HISTORY`, `FX_REFERENCE_RATE`, `PRICE_ADJUSTMENT_UNVERIFIED` 경고는 각각 기간 부족, 실제 환전가와의 차이, 조정 여부를 확인하지 못한 제공자 데이터의 한계를 뜻한다.

### FinancialHealthResult

```json
{
  "monthly_surplus_krw": 1100000,
  "emergency_runway_months": 2.63,
  "leverage_ratio": 0.4,
  "estimated_monthly_interest_krw": 20000,
  "reported_total_debt_krw": 14000000,
  "unavailable_reasons": []
}
```

`emergency_runway_months`와 `leverage_ratio`는 `number | null`이다. 다른 금액 필드는 `integer`다.

### ScenarioResult

```json
{
  "scenario_key": "down_20",
  "label": "20% 하락",
  "assumed_return_rate": -0.2,
  "price_change_rate": -0.2,
  "exchange_rate_change_rate": 0.0,
  "projected_investment_value_krw": 8000000,
  "investment_pnl_krw": -2000000,
  "investment_loss_krw": 2000000,
  "reported_total_debt_krw": 14000000,
  "net_investment_equity_krw": 4000000,
  "loss_to_equity_ratio": 0.333333,
  "loss_to_emergency_fund_ratio": 0.4,
  "loss_to_monthly_fixed_expenses": 1.333333,
  "estimated_annual_interest_krw": 240000,
  "estimated_monthly_interest_krw": 20000,
  "recovery_required_rate": 0.25,
  "unavailable_reasons": []
}
```

`scenario_key`는 `up_20 | flat | down_10 | down_20 | down_30 | down_40 | down_50 | historical_mdd | custom`이다. 세 개의 손실 대비 비율과 `recovery_required_rate`는 `number | null`이다.
고정 및 `custom` 시나리오의 `assumed_return_rate`는 원화 기준 최종 수익률이며 `(1 + price_change_rate) × (1 + exchange_rate_change_rate) - 1`로 계산한다. `historical_mdd`는 이미 원화 기준으로 계산된 과거 낙폭이므로 두 변동률 필드는 `null`이고 환율 충격을 중복 적용하지 않는다.

## 3. 엔드포인트

### `GET /health`

요청 본문 없이 서버 연결 상태를 반환한다.

```json
{
  "status": "ok"
}
```

### `POST /api/v1/financial-health/analyze`

요청은 `FinancialProfileInput`, 응답은 `FinancialHealthResult`다.

### `GET /api/v1/instruments/search?q={query}`

응답은 `Instrument[]`다. 빈 검색어는 `VALIDATION_ERROR`를 반환한다. Twelve Data 사용 시 미국 상장 주식·ETF를 검색한다. 일부 주요 종목의 한글 별칭은 티커로 변환한 후 제공자 결과를 검증해 반환한다. 별칭에 없는 한글 검색어는 빈 배열을 반환하며 지수 자체는 검색 대상이 아니다.

### `GET /api/v1/market-risk/{market}/{symbol}?start_date={date}&end_date={date}`

응답은 `MarketRiskResult`다. `market`과 `symbol`은 URL 인코딩하며 기간은 양 끝 날짜를 포함한다.

### `POST /api/v1/stress-tests/analyze`

요청:

```json
{
  "financial_profile": {
    "monthly_income_krw": 3000000,
    "monthly_fixed_expenses_krw": 1500000,
    "emergency_fund_krw": 5000000,
    "existing_loan_balance_krw": 10000000,
    "monthly_debt_payment_krw": 400000,
    "planned_investment_krw": 10000000,
    "equity_amount_krw": 6000000,
    "borrowed_amount_krw": 4000000,
    "annual_loan_rate": 0.06
  },
  "historical_mdd_rate": -0.31,
  "exchange_rate_change_rate": -0.1,
  "custom_return_rate": -0.175
}
```

실제 `financial_profile`에는 `FinancialProfileInput` 전체가 들어간다. `historical_mdd_rate`는 `number | null`이다. 응답은 순서가 고정된 `ScenarioResult[]`이며 `up_20`, `flat`, `down_10`, `down_20`, `down_30`, `down_40`, `down_50` 다음에 MDD가 있으면 `historical_mdd`, 직접 입력이 있으면 마지막에 `custom`이 온다. 모바일의 차입투자 Stress Test는 반환된 전체 시나리오를 선택·비교해 표시한다.
`custom_return_rate`는 선택 필드이며 생략하거나 `null`이면 직접 입력 시나리오를 반환하지 않는다. 허용 범위는 `-1..1`(-100%..+100%)이고 종목 가격의 변동 가정이다. 0인 분모·100% 손실도 기존 `ScenarioResult`의 null 및 사유 코드 규칙을 따른다.
`exchange_rate_change_rate`는 선택 필드이며 생략 시 `0`이다. 허용 범위는 `-0.5..0.5`다. 미국 종목의 원화 환산 시나리오에서만 사용하고, 국내 종목 화면은 `0`을 전달한다. 이 값은 실시간 환율이나 미래 예측이 아닌 독립적인 가정이다. 종목 정보가 없는 이 엔드포인트 자체는 통화 종류를 검증하지 않는다.

### `POST /api/v1/combined-analyses`

요청:

```json
{
  "financial_profile": {
    "monthly_income_krw": 3000000,
    "monthly_fixed_expenses_krw": 1500000,
    "emergency_fund_krw": 5000000,
    "existing_loan_balance_krw": 10000000,
    "monthly_debt_payment_krw": 400000,
    "planned_investment_krw": 10000000,
    "equity_amount_krw": 6000000,
    "borrowed_amount_krw": 4000000,
    "annual_loan_rate": 0.06
  },
  "instrument": {
    "symbol": "005930",
    "market": "KRX",
    "name": "삼성전자",
    "currency": "KRW"
  },
  "period_start": "2023-01-02",
  "period_end": "2025-12-30"
}
```

응답:

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "calculated_at": "2026-09-11T12:00:00Z",
  "calculation_version": "1.0.0",
  "financial_health": {},
  "market_risk": {},
  "mdd_impact": {},
  "scenarios": [],
  "warnings": [],
  "disclaimer": "교육 및 금융위험 인지 목적이며 투자 자문이 아닙니다. 과거 성과는 미래 결과를 보장하지 않습니다."
}
```

응답 예시의 빈 객체와 배열은 위에 정의한 공통 타입이 들어갈 위치를 축약한 것이다. 실제 API는 해당 타입의 필드를 생략하지 않는다. `mdd_impact`는 `ScenarioResult | null`, `market_risk`는 `MarketRiskResult | null`이다. 주가 데이터 실패 시 두 값은 `null`, 고정 시나리오는 계속 반환한다.

### `POST /api/v1/explanations`

LLM에 전달 가능한 최소 결과만 받는다.

```json
{
  "scenario_key": "historical_mdd",
  "assumed_return_rate": -0.31,
  "investment_loss_krw": 3100000,
  "loss_to_equity_ratio": 0.516667,
  "loss_to_emergency_fund_ratio": 0.62,
  "loss_to_monthly_fixed_expenses": 2.066667,
  "net_investment_equity_krw": 2900000,
  "estimated_monthly_interest_krw": 20000,
  "market_max_drawdown_rate": -0.31,
  "warnings": []
}
```

응답:

```json
{
  "source": "llm",
  "summary": "과거 최대 하락폭을 적용한 경우의 금융 충격을 설명하는 검증된 문장",
  "caution": "가정에 따른 결과이며 투자 추천이나 미래 예측이 아닙니다.",
  "fallback_reason": null
}
```

`source`는 `llm | template`이다. `fallback_reason`은 `null | not_configured | provider_unavailable | safety_rejected`이며, `source=llm`이면 `null`이다. 서버는 AI에 원본 금액·비율 대신 검증된 결과의 정성적 상태와 사용 가능한 자리표시자 이름만 보내고, 통과한 문장에 서버 계산값을 대입한다. 출력에 새로운 숫자, 투자 추천, 미래 예측이 포함됐는지 검사하고 부적합하면 정적 template 응답으로 대체하며 사유를 표시한다. 외부 오류 본문이나 키는 응답에 포함하지 않는다. 이전 서버의 응답에는 이 선택 필드가 없을 수 있다.

## 4. 공통 오류

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "입력값을 확인해 주세요.",
    "field_errors": [
      {
        "field": "equity_amount_krw",
        "reason": "INVESTMENT_SUM_MISMATCH"
      }
    ],
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

오류 코드는 `VALIDATION_ERROR`, `INSTRUMENT_NOT_FOUND`, `INSUFFICIENT_PRICE_DATA`, `MARKET_DATA_UNAVAILABLE`, `EXPLANATION_UNAVAILABLE`, `INTERNAL_ERROR` 중 하나다. 내부 예외, 외부 API 본문, secret은 응답에 포함하지 않는다.

## 5. 현금흐름·생활 충격 확장 (2026-11-02)

영향 범위: financial-health의 기존 입력을 재사용하고 stress-test가 계산·화면을 소유한다. market-risk의 평가손익과 현금을 분리하며 combined-report·LLM의 기존 요청·응답은 변경하지 않는다. 이 확장은 새 엔드포인트이며 기존 서버에는 배포 전까지 존재하지 않는다.

### `POST /api/v1/stress-tests/cash-flow`

```text
CashFlowRequest {
  financial_profile: FinancialProfileInput
  months?: integer = 6                  // 3 | 6 | 12
  loan_term_months?: integer = 36        // 1..360
  repayment_method?: "interest_only" | "equal_principal" = "interest_only"
  income_change_rate?: number = 0       // -1..0
  expense_change_rate?: number = 0      // 0..1
  loan_rate_change?: number = 0         // 0..(1 - annual_loan_rate), +2%p = 0.02
  price_change_rate?: number = 0        // -1..1
  exchange_rate_change_rate?: number = 0 // -0.5..0.5; KRW는 0
  investment_currency?: "KRW" | "USD" = "KRW"
}
MonthlyCashFlowResult {
  month: integer
  income_krw: integer
  fixed_expenses_krw: integer
  existing_debt_payment_krw: integer
  investment_interest_krw: integer
  investment_principal_payment_krw: integer
  monthly_net_cash_krw: integer
  cash_balance_krw: integer
  cash_shortfall_krw: integer
  investment_loan_balance_krw: integer
  cumulative_interest_krw: integer
}
CashFlowPathResult {
  monthly_points: MonthlyCashFlowResult[]
  total_interest_krw: integer
  total_principal_paid_krw: integer
  ending_cash_balance_krw: integer
  ending_loan_balance_krw: integer
  first_shortfall_month: integer | null
}
CashFlowResult {
  calculation_version: string
  months: integer
  initial_cash_krw: integer
  baseline: CashFlowPathResult
  shocked: CashFlowPathResult
  investment_effect: ScenarioResult
  assumptions: string[]
}
```

`baseline`은 같은 차입·기간·상환 방식에서 충격을 모두 0으로 둔 결과다. `shocked`는 소득·고정지출·투자용 금리 변화만 적용한 결과다. 모든 금액 입력은 이 엔드포인트에서 최대 `10^15`원으로 제한한다.

- 시작 현금은 투자자금과 별도로 남겨 둔 `emergency_fund_krw`다. 자기자본을 다시 차감하지 않는다.
- 월 현금수지 = 변경된 소득 − 변경된 고정지출 − 기존 월 대출 상환액 − 투자용 월 이자 − 투자용 월 원금상환액.
- 매월 이자는 해당 월 시작 투자용 대출잔액 × 적용 연이율 / 12다. 이자·원금 지출을 원 단위 `ROUND_HALF_UP`으로 확정한 후 누적해 월별 표와 합계가 일치한다.
- `interest_only`도 만기 월에는 남은 투자용 원금을 전액 상환한다. `equal_principal`은 최초 원금/만기 개월을 매월 상환하고 마지막 월에 원 단위 잔액을 정산한다. 상환 후 이자를 부과하지 않는다.
- 기존 대출은 금리·상환 방식 정보가 없으므로 월 상환액을 고정한다. `investment_loan_balance_krw`는 투자용 대출만 의미한다.
- `cash_balance_krw`는 가정된 누적 현금여력이며 음수는 자금 부족분이다. 자동 추가차입·연체이자를 계산하지 않는다. `cash_shortfall_krw = max(-cash_balance_krw, 0)`이다. 첫 음수 월만 `first_shortfall_month`에 표시한다.
- `investment_effect`는 기간 시작의 주가·환율 충격을 기존 `custom` 계산으로 표시한다. 이후 가격 변화·배당·매도 현금 유입은 가정하지 않으며, 평가손익을 월 현금 잔액에서 더하거나 빼지 않는다. 과거 MDD나 미래 예측값을 입력하는 계약이 아니다.
- 재무 원본이나 월별 결과를 LLM·로그·서버 저장소에 전달하지 않는다. 결과는 사용자가 지정한 가정의 산술 계산이며 실제 상품 상환표나 투자 가능 여부 판정이 아니다.

## 6. 과거 가격 그래프 확장 (2026-11-02)

### `GET /api/v1/market-risk/{market}/{symbol}/history?start_date={date}&end_date={date}`

```text
MarketPricePoint {
  date: date
  krw_price_index: number
  usd_price_index: number | null
  fx_rate_as_of: date | null
}
MarketPriceHistoryResult {
  market_risk: MarketRiskResult
  points: MarketPricePoint[]
}
```

기존 `MarketRiskResult` 계약은 유지한다. 이 새 엔드포인트는 같은 시계열의 요약과 날짜별 그래프를 함께 반환한다. 모바일은 사용자가 그래프 보기를 선택할 때만 조회하며 요약 조회 때의 원래 시작·종료일을 재사용해 제공자 캐시를 활용한다. 요약과 그래프의 종목·기준일·MDD·관측치·고점/저점/회복일이 달라지면 모바일은 그래프 표시를 거절하고 재조회를 안내한다. 그래프 실패는 기존 요약을 지우지 않는다.

- 지수는 첫 관측 가격을 100으로 맞춘 `가격 / 첫 가격 × 100`이다. 110은 첫날 대비 +10%이며 명목 주가가 아니다. 표시는 소수점 6자리로 반올림한다.
- 원화 지수는 MDD 계산에 사용한 날짜별 원화 가격, 달러 지수는 같은 관측일의 분할 조정 USD 종가를 사용한다. 환율·조정 기준과 Basic 비공개 시연 범위는 기존과 같다.
- 달러 원자료가 없으면 값을 역산하거나 추정하지 않는다. 해당 관측의 `usd_price_index`는 `null`이고 `USD_PRICE_UNAVAILABLE` 경고를 추가한다. 첫 달러 가격이 없으면 달러 곡선 전체를 생략한다.
- 관측이 2개 미만이거나 첫 원화 가격이 0이면 `points=[]`로 반환한다. 중복 날짜·비정상 가격은 제공자 오류로 처리한다. 휴장일 행을 만들거나 다운샘플링하지 않는다.
- MDD 표식과 음영은 원화 요약의 고점·저점·회복일을 그대로 사용한다. 가로축은 관측 순서로 표시한다.
- `PricePoint.usd_adjusted_close`는 어댑터 내부에만 추가하는 선택 속성이며 기존 financial-health·stress-test·combined-report 및 LLM JSON은 변경하지 않는다.
- 공개 운영 Nginx의 `/market-risk/` 차단은 이 하위 경로에도 적용한다. 공개 오프라인 그래프는 독립적으로 만든 가상 곡선과 계산한 가상 지표만 사용한다.
