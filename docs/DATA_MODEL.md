# 핵심 데이터 모델

## 1. 모델링 원칙

MVP의 모델은 데이터베이스 테이블이 아니라 FastAPI 요청·응답과 계산 함수에서 사용하는 비영속 모델이다. 재무 입력은 요청 처리 동안만 메모리에 존재하며 저장하거나 로그에 남기지 않는다.

현재 Flutter DTO와 FastAPI Pydantic schema는 아래 모델을 구현하고 있다. 모델 변경은 [API_CONTRACT.md](./API_CONTRACT.md), 양쪽 구현 타입과 contract test를 같은 PR에서 수정할 때만 허용한다.

- JSON 필드는 `snake_case`로 통일한다.
- 금액은 KRW 정수로 전송하고 Python 내부에서는 정수 또는 `Decimal`로 계산한다.
- 비율은 소수로 전송한다. 예: 20%는 `0.20`, 30% 하락은 `-0.30`이다.
- 날짜는 `YYYY-MM-DD`, 시각은 UTC ISO 8601 문자열을 사용한다.
- 계산할 수 없는 값은 0이 아니라 `null`과 사유 코드를 사용한다.
- 기본 계산은 API 직렬화 시 금액은 원 단위, 비율은 소수점 6자리 `ROUND_HALF_UP`을 적용한다. 월별 현금흐름은 실제 원 단위 지출을 합산하는 가정이므로 월별 이자·소득·지출과 정기 원금 상환액을 먼저 원 단위 반올림하며 마지막 상환에서 원금 잔여액을 정산한다.
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

`Instrument.instrument_type`은 `stock | etf`이며 기존 입력에서 생략하면 `stock`이다. `PricePoint`는 `date`, `adjusted_close`, 선택적 `fx_date`로 구성된다. Twelve Data 미국 주식·ETF는 분할 조정된 USD 일별 종가(배당·분배금 제외)에 ECB 참고 환율을 곱한 KRW 가격이다. `fx_date`는 미국 종목 관측에 적용한 환율 기준일이다. 외부 제공자의 필드명을 그대로 도메인에 노출하지 않는다.

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
`fx_rate_as_of`는 마지막 관측에 적용한 환율 날짜이며 국내 종목은 `null`이다. 미국 종목의 위험 지표는 원화 가격 시계열 기준이다.

### MarketPriceHistoryResult

기존 `market_risk` 요약과 `points`를 묶는다. 각 관측은 `date`, 첫 관측값 100 기준의 `krw_price_index`·선택적 `usd_price_index`, `fx_rate_as_of`다. 내부 `PricePoint.usd_adjusted_close`는 환산 전 USD 종가를 보존한다. 달러 관측이 없으면 곡선을 생략하거나 끊어서 표시하고 임의 환율을 만들지 않는다. 단위·계약은 API 계약 6절을 따른다.

### CashFlowRequest와 CashFlowResult

기존 `financial_profile`에 기간, 투자용 대출 만기·상환 방식, 소득·지출·금리·주가·환율 가정을 추가한다. 응답은 충격 전후 `baseline`·`shocked`의 월별 수입, 지출, 이자, 원금 상환, 순현금, 현금 잔액, 잔여 투자용 원금, 누적 이자를 가진다. `investment_effect`는 현금과 분리된 시점 평가 충격이다. 현금 시작값은 투자 후 남긴 비상자금이다. 기존 대출 잔액으로 새 월별 상환 경로를 추정하지 않는다. 정확한 필드·반올림·범위는 API 계약 5절을 따른다.

모바일의 `CashFlowSnapshot`은 계산에 쓴 요청과 응답을 함께 보관하는 화면 내 A·B 슬롯이다. 서버 모델·DB·분석 이력을 추가하지 않는다.

### ScenarioResult

`scenario_key`는 `up_20`, `flat`, `down_10`, `down_20`, `down_30`, `down_40`, `down_50`, `historical_mdd`, `custom` 중 하나다. `custom`은 직접 입력 충격과 현금흐름의 별도 평가 충격에 사용한다. 각 결과는 다음을 가진다.

- 가정: `label`, 원화 기준 `assumed_return_rate`, `price_change_rate`, `exchange_rate_change_rate`
- 자산·손익: `projected_investment_value_krw`, `investment_pnl_krw`, `investment_loss_krw`
- 부채·지분: `reported_total_debt_krw`, `net_investment_equity_krw`
- 충격: `loss_to_equity_ratio`, `loss_to_emergency_fund_ratio`, `loss_to_monthly_fixed_expenses`
- 부담·회복: `estimated_annual_interest_krw`, `estimated_monthly_interest_krw`, `recovery_required_rate`
- 예외: `unavailable_reasons`

`investment_pnl_krw`는 상승 시 양수, 하락 시 음수다. `investment_loss_krw`는 손실이 없으면 0인 비음수 값이다. 가격 충격만 적용하므로 부채 원금과 월 이자는 시나리오별로 변하지 않는다.
고정 시나리오는 주가·환율 충격을 곱해 원화 수익률을 만든다. 과거 MDD는 이미 원화 기준이므로 두 개별 충격 필드는 `null`이다.

### CombinedAnalysisResult

개인 금융체력과 종목 과거 위험을 한 Report로 묶는다.

- 재현 정보: `request_id`, `calculated_at`, `calculation_version`
- 계산 결과: `financial_health`, `market_risk`, `mdd_impact`, `scenarios`
- 근거와 제한: `warnings`, `disclaimer`

`mdd_impact`는 종목의 `max_drawdown_rate`를 사용자의 투자금에 적용한 `ScenarioResult`다. 동일 값이 `scenarios`의 `historical_mdd` 항목에도 나타나야 한다.

## 4. AI 설명 모델

위험 이해 체험의 별도 `QuizRequest`는 재현용 `seed`만 받는다. `QuizResult`는 출처·대체 사유와 서로 다른 주제의 5개 `QuizQuestion`을 가진다. 각 문제의 가상 전제·선택지·정답 위치·계산식·설명은 서버가 확정하며 LLM은 제목·도입만 구성한다. 사용자 재무·문제 선택·정오답 기록을 서버에 보내지 않는다. 모바일의 같은 DTO는 계약의 `correct_index` 등 `snake_case`를 사용한다.

`ExplanationInput`은 결합 Report 전체가 아니라 선택한 결과의 최소 파생값만 가진다. 사용자 이름, 원본 소득, 원본 대출 목록, 비상자금 원금, 투자 의도는 포함하지 않는다.

허용 값은 시나리오 키·수익률, 이미 계산된 손실, 자기자본·비상자금·고정지출 대비 비율, 순투자지분, 월 이자, 종목 MDD, 경고 코드다. `ExplanationResult`는 설명 문자열과 `llm` 또는 `template` 출처만 가지며 금융 숫자의 권위 있는 저장소가 아니다. OpenAI 연결이 실패하거나 출력 검증을 통과하지 못하면 동일 입력으로 만든 `template` 설명을 반환한다.

## 5. 계산 불가 사유 코드

- `ZERO_EQUITY`: 자기자본이 0임
- `ZERO_EMERGENCY_FUND`: 비상자금이 0임
- `ZERO_FIXED_EXPENSES`: 고정지출이 0임
- `ZERO_ESSENTIAL_OUTFLOW`: 고정지출과 월 상환액 합이 0임
- `NO_FINITE_RECOVERY_RATE`: 100% 손실로 유한한 회복률이 없음
- `INSUFFICIENT_PRICE_DATA`: 주가 관측치가 부족함
- `MARKET_DATA_UNAVAILABLE`: 주가 API를 사용할 수 없음

## 6. MVP 이후 모델

3·6·12개월 현금흐름·누적 이자·상환 방식은 현재 비영속 모델로 구현했다. 계정과 저장 이력은 추가하지 않는다.

2026-11-02 운영 배포는 모델을 추가 변경하지 않았다. 같은 현금흐름·문제 DTO를 HTTPS에서 제공하며 시세 관련 DTO의 공개 제공은 차단한다. Google Drive에는 서명 파일의 암호화 백업만 보관하고 사용자 재무정보·시세·풀이 기록의 저장 모델을 만들지 않는다.
