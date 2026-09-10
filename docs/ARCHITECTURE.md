# 시스템 아키텍처

## 1. MVP 기술 스택

- **모바일:** Flutter + Dart(Android)
- **API·계산:** FastAPI + Python
- **외부 연동:** 주가 데이터 API, 제한적 LLM API
- **테스트·정적 검사:** pytest, Ruff, Flutter test, Flutter analyze
- **배포:** Naver Cloud, KT Cloud, NHN Cloud 중 공모전 제공 조건에 맞는 한 곳

MVP에는 Supabase, PostgreSQL, 회원가입·로그인, 서버 분석 이력, `packages/contracts` 별도 패키지를 사용하지 않는다. 필요한 데이터는 한 요청 안에서 처리하고 사용자 재무 원본은 응답 후 폐기한다. 외부 API 응답은 제공자 약관이 허용할 때만 프로세스 메모리에 짧게 캐시한다.

## 2. 전체 구조

```text
Flutter Mobile
  ├─ 재무 입력 및 시나리오 화면
  ├─ 과거 위험 및 결합 Report
  └─ HTTPS/JSON
          ↓
Single FastAPI Service
  ├─ financial-health   결정론적 재무 계산
  ├─ market-risk       주가 조회 및 MDD/변동성 계산
  ├─ stress-test       고정 가격 충격 및 회복률 계산
  ├─ combined-report   개인×종목 결합 및 결과 구성
  └─ integrations
       ├─ Stock API Adapter
       └─ LLM Explanation Adapter
```

FastAPI 한 개만 배포하며 마이크로서비스, 메시지 큐, Kubernetes, 영속 데이터베이스를 두지 않는다. 클라우드가 바뀌어도 환경변수와 실행 명령만 바뀌도록 표준 ASGI 애플리케이션으로 유지한다.

## 3. Vertical Slice 저장소 구조

```text
apps/
  mobile/
    lib/
      features/
        financial_health/
        market_risk/
        stress_test/
        combined_report/
      shared/
    test/
  api/
    app/
      features/
        financial_health/   # route, schema, calculation
        market_risk/        # route, schema, calculation
        stress_test/        # route, schema, calculation
        combined_report/    # route, schema, explanation
      integrations/         # stock_api, llm
      shared/               # errors, settings, disclaimers
    tests/
docs/API_CONTRACT.md        # 필드명과 API의 단일 기준
```

각 담당자는 한 Slice의 UI, API, 계산 또는 연동, 테스트를 끝까지 수정한다. 공유 코드는 두 Slice 이상에서 같은 동작이 확인된 뒤 `shared/`로 이동한다. 모바일과 API는 `API_CONTRACT.md`의 동일한 `snake_case` JSON 필드를 사용한다.

## 4. 계산과 외부 연동 경계

1. 모바일과 FastAPI가 각각 입력 형식을 검증한다.
2. 주가 어댑터가 가격 데이터와 출처·기준일을 반환한다.
3. 계산 함수가 외부 I/O 없이 금융체력, 시장 위험, 고정 시나리오, 결합 영향을 계산한다.
4. Report 조합기가 계산 버전, 입력 근거, 경고와 면책을 붙인다.
5. LLM 어댑터에는 Report 전체가 아닌 최소 설명용 결과만 전달한다.
6. 모바일은 숫자 Report를 먼저 표시하고 검증된 AI 설명을 부가 정보로 표시한다.

외부 API 장애가 계산식을 바꾸어서는 안 된다. 시세가 없으면 시장·결합 분석을 중단하고 재무체력과 고정 하락 시나리오는 계속 제공한다. LLM 장애 시 정적 설명으로 대체한다.

## 5. LLM 안전 경계

LLM 입력에는 사용자 이름, 원본 소득·대출·비상자금 목록, 종목 매수 의도, 식별자를 포함하지 않는다. 허용 입력은 시나리오 이름, 이미 계산된 손실과 비율, 기준일, 경고 코드처럼 설명에 직접 필요한 값뿐이다.

LLM 출력은 문자열 설명이며 권위 있는 데이터 모델에 다시 합치지 않는다. 응답에 계약에 없는 숫자, 미래 가격, 수익 가능성, 매수·매도 또는 투자 가능 판단이 포함되면 폐기한다. 설명 유무와 관계없이 Python 계산 JSON이 화면의 유일한 수치 근거다.

## 6. 배포와 보안

- FastAPI는 공모전에서 제공하는 Naver Cloud, KT Cloud, NHN Cloud 중 하나의 단일 애플리케이션으로 배포한다.
- 제공 조건, 팀 경험, 배포 난이도를 비교해 한 사업자를 선택하고 선택 근거를 기록한다.
- 주가·LLM API 키는 클라우드 secret 또는 서버 환경변수로만 주입한다. 모바일 앱에는 공개 API URL만 둔다.
- HTTPS, 입력 크기 제한, 외부 API timeout과 제한된 retry만 우선 적용한다.
- 요청 로그에는 요청 ID, 처리시간, 상태 코드, 데이터 기준일만 남기고 재무값과 LLM payload를 제외한다.

## 7. MVP 이후 확장

계정, 영속 저장, 기간별 누적 이자, 포트폴리오는 사용자 검증 후 별도 아키텍처 결정으로 추가한다. 현재 구조를 미리 복잡하게 만들어 대비하지 않는다.
