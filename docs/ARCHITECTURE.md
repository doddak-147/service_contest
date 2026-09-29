# 시스템 아키텍처

## 1. MVP 기술 스택

- **모바일:** Flutter + Dart(Android)
- **API·계산:** FastAPI + Python
- **외부 연동:** Naver Finance 주가 어댑터, OpenAI-compatible LLM API
- **테스트·정적 검사:** pytest, Ruff, Flutter test, Flutter analyze
- **배포:** Naver Cloud Server(Ubuntu 24.04), Nginx, Uvicorn, HTTPS

MVP에는 Supabase, PostgreSQL, 회원가입·로그인, 서버 분석 이력, `packages/contracts` 별도 패키지를 사용하지 않는다. 필요한 데이터는 한 요청 안에서 처리하고 사용자 재무 원본은 응답 후 폐기한다. 외부 API 응답은 제공자 약관이 허용할 때만 프로세스 메모리에 짧게 캐시한다.

## 2. 전체 구조

```text
Flutter Mobile
  ├─ 재무 입력 및 시나리오 화면
  ├─ 과거 위험 및 결합 Report
  └─ HTTPS/JSON (`API_BASE_URL`)
          ↓
DuckDNS Domain + TLS
          ↓
Nginx Reverse Proxy (80/443)
          ↓
Single FastAPI Service (Uvicorn/systemd)
  ├─ financial-health   결정론적 재무 계산
  ├─ market-risk       주가 조회 및 MDD/변동성 계산
  ├─ stress-test       고정 가격 충격 및 회복률 계산
  ├─ combined-report   개인×종목 결합 및 결과 구성
  └─ integrations
       ├─ Stock API Adapter
       └─ LLM Explanation Adapter
```

FastAPI 한 개만 배포하며 마이크로서비스, 메시지 큐, Kubernetes, 영속 데이터베이스를 두지 않는다. Nginx가 HTTPS를 종료하고 localhost의 Uvicorn으로 전달한다. 클라우드가 바뀌어도 환경변수와 실행 명령만 바뀌도록 표준 ASGI 애플리케이션으로 유지한다.

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

- 운영 주소는 `https://service-contest-2026-api.duckdns.org`이며 `/health` 응답으로 상태를 확인한다.
- Naver Cloud의 VPC·Public Subnet 안에 Ubuntu 24.04 Micro 서버 1대를 두고 10GB 기본 스토리지를 사용한다.
- Nginx가 80/443 요청을 FastAPI의 localhost 포트로 전달하며 TLS 인증서를 적용한다. SSH는 관리자의 고정 IP로만 제한한다.
- Uvicorn은 systemd 서비스로 관리하고 환경변수는 권한을 제한한 `/etc/service-contest.env`에서 주입한다.
- 주가·LLM API key는 서버 환경변수에만 두며 모바일에는 공개 `API_BASE_URL`만 전달한다. Native Flutter 요청에는 브라우저 CORS가 필요하지 않아 운영 기본 허용 origin은 비워 둔다.
- 외부 API에는 timeout을 적용한다. 요청 로그에는 재무 원본과 LLM payload를 남기지 않고 오류 로그에서도 secret을 마스킹한다.

현재 배포는 공모전 시연용 단일 서버 구성이다. 공인 IP, 도메인과 인증서가 바뀌면 모바일 빌드의 `API_BASE_URL`과 운영 문서를 함께 갱신한다.

## 7. MVP 이후 확장

계정, 영속 저장, 기간별 누적 이자, 포트폴리오는 사용자 검증 후 별도 아키텍처 결정으로 추가한다. 현재 구조를 미리 복잡하게 만들어 대비하지 않는다.
