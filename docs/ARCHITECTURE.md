# 시스템 아키텍처

## 1. MVP 기술 스택

- **모바일:** Flutter + Dart(Android)
- **API·계산:** FastAPI + Python
- **외부 연동:** Twelve Data 미국 상장 주식·ETF 일별 시세, ECB 일별 기준 환율, OpenAI-compatible LLM API
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
Nginx (80 → HTTPS, 443 TLS)
  ├─ 공개 종목 검색·과거 위험·결합 분석 → JSON 503
  └─ 나머지 API → localhost:8000
          ↓
Single FastAPI Service (Uvicorn/systemd)
  ├─ financial-health   결정론적 재무 계산
  ├─ market-risk       주가 조회, MDD/변동성, 원화·달러 가격 그래프
  ├─ stress-test       고정 충격, 회복률, 월별 현금흐름·생활 충격
  ├─ combined-report   개인×종목 결합 및 결과 구성
  ├─ foundation        가상 문제 계산, AI 도입 문구·오프라인 체험 진입
  └─ integrations
       ├─ Stock API Adapter (Twelve Data 미국 주식·ETF, 기본 비활성화)
       ├─ ECB FX Adapter (EUR 교차 환율 → KRW/USD)
       └─ LLM Explanation Adapter
```

FastAPI 한 개만 배포하며 마이크로서비스, 메시지 큐, Kubernetes, 영속 데이터베이스를 두지 않는다. Nginx가 HTTPS를 종료하고 localhost의 Uvicorn으로 전달한다. 클라우드가 바뀌어도 환경변수와 실행 명령만 바뀌도록 표준 ASGI 애플리케이션으로 유지한다.

## 3. Vertical Slice 저장소 구조

```text
apps/
  mobile/
    lib/
      features/
        foundation/
        financial_health/
        market_risk/
        stress_test/
        combined_report/
        offline_demo/
      shared/
    test/
  api/
    app/
      features/
        foundation/         # health, 가상 문제 구성과 AI 제목·도입
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
   미국 종목은 일별 USD 종가에 같은 날 또는 5일 이내 직전 ECB 참고 환율을 곱해 KRW 시계열을 만든다. 환율은 서버 메모리에 최대 6시간 캐시하고 원본 재무정보와 함께 저장하지 않는다.
3. 계산 함수가 외부 I/O 없이 금융체력, 시장 위험, 고정 시나리오, 결합 영향을 계산한다.
4. Report 조합기가 계산 버전, 입력 근거, 경고와 면책을 붙인다.
5. LLM 어댑터에는 Report 전체가 아닌 최소 설명용 결과만 전달한다.
6. 모바일은 숫자 Report를 먼저 표시하고 검증된 AI 설명을 부가 정보로 표시한다.

외부 API 장애가 계산식을 바꾸어서는 안 된다. 시세가 없으면 시장·결합 분석을 중단하고 재무체력과 고정 하락 시나리오는 계속 제공한다. LLM 장애 시 정적 설명으로 대체한다.
주가 어댑터는 `STOCK_DATA_PROVIDER=twelve`와 서버 환경변수 `TWELVE_DATA_API_KEY`를 함께 설정할 때만 작동한다. 기본값 `disabled`는 실제 시세 대신 가짜 값을 보여주지 않고 503을 반환한다. Twelve Data Basic에서는 미국 상장 주식·ETF만 검색하고 지수 자체는 제외하며 API 키는 HTTP 인증 헤더로 전달한다. 과거 조회에는 일별 분할 조정 종가를 사용하고 검색·조회 결과는 제한된 시간 동안 프로세스 메모리에만 캐시한다. `Instrument.instrument_type`으로 주식과 ETF를 구분하고 결합 Report까지 전달한다.
미국 종목의 고정 시나리오는 `(1 + 주가 변동률) × (1 + 원/달러 환율 변동률) - 1`을 Python에서 계산한다. 원화 환산 과거 MDD에는 환율 충격을 중복 적용하지 않는다. GitHub Actions는 ECB 소스의 최근 갱신 여부만 감시하고 환율 공급·캐시·배포 경로에는 포함하지 않는다.

가격 그래프는 어댑터가 보존한 원본 USD 종가와 KRW 종가를 동일 요청 범위에서 정규화해 `/market-risk/{market}/{symbol}/history`로 제공한다. 기존 위험 요약과 관측치·MDD 날짜가 일치해야 모바일이 표시한다. 공개 Nginx의 기존 `/market-risk/` 차단 범위에 새 경로도 포함된다.

현금흐름 `/stress-tests/cash-flow`는 외부 I/O가 없는 별도 계산으로 월별 이자·원금 상환·현금 잔액을 산출한다. 투자 평가 충격은 기존 시나리오 계산을 재사용하되 현금과 섞지 않는다. A·B는 모바일 화면 메모리에 입력·응답을 함께 보관하고 화면 종료 시 폐기한다. 오프라인 이해 사례와 공개용 가상 시계열은 고정 합성값이며 서버를 호출하지 않는다. 새 현금흐름 결과·재무 원본을 LLM에 추가 전송하지 않는다. 현금흐름과 AI 문제 API는 2026-11-02 운영에 배포했다. 가격 이력 API 소스도 포함하지만 공개 요청은 기존 시세 차단 대상이다.

## 5. LLM 안전 경계

위험 이해 체험은 foundation의 `/api/v1/risk-learning/quizzes`를 사용한다. 서버가 가상 수치·선택지·정답을 확정하고 같은 `LLM_*` 설정으로 제목·도입 문구만 요청한다. LLM 입력은 주제명뿐이며 새 API가 사용자 재무정보나 시세를 받지 않는다. 검증된 도입 문구만 프로세스 메모리에 10분 보관하고 풀이 기록은 저장하지 않는다. 오프라인 체험은 API 없이 자체 문제 5개를 구성한다.

LLM 입력에는 사용자 이름, 원본 소득·대출·비상자금 목록, 종목 매수 의도, 식별자를 포함하지 않는다. 허용 입력은 시나리오 이름, 이미 계산된 손실과 비율, 기준일, 경고 코드처럼 설명에 직접 필요한 값뿐이다.

LLM 출력은 문자열 설명이며 권위 있는 데이터 모델에 다시 합치지 않는다. 응답에 계약에 없는 숫자, 미래 가격, 수익 가능성, 매수·매도 또는 투자 가능 판단이 포함되면 폐기한다. 설명 유무와 관계없이 Python 계산 JSON이 화면의 유일한 수치 근거다.

## 6. 배포와 보안

- 운영 주소는 `https://service-contest-2026-api.duckdns.org`이며 `/health` 응답으로 상태를 확인한다.
- Naver Cloud의 VPC·Public Subnet 안에 Ubuntu 24.04 Micro 서버 1대를 두고 10GB 기본 스토리지를 사용한다.
- Nginx가 80의 도메인 요청을 HTTPS로 전환하고 443에서 TLS를 종료한다. 공개 종목 검색·과거 위험·결합 분석은 Nginx에서 JSON 503으로 차단하고 나머지 요청만 FastAPI의 localhost 포트로 전달한다. SSH는 관리자의 고정 IP로만 제한한다.
- Uvicorn은 systemd 서비스로 관리하고 환경변수는 권한을 제한한 `/etc/service-contest.env`에서 주입한다.
- 주가·LLM API key는 서버 환경변수에만 두며 모바일에는 공개 `API_BASE_URL`만 전달한다. Native Flutter 요청에는 브라우저 CORS가 필요하지 않아 운영 기본 허용 origin은 비워 둔다.
- 외부 API에는 timeout을 적용한다. 요청 로그에는 재무 원본과 LLM payload를 남기지 않고 오류 로그에서도 secret을 마스킹한다.

현재 배포는 공모전 시연용 단일 서버 구성이다. 공인 IP, 도메인과 인증서가 바뀌면 모바일 빌드의 `API_BASE_URL`과 운영 문서를 함께 갱신한다. 최신 Settings는 `APP_ENV=production`에서 Twelve Data 설정을 거부하며, 배포 실행 명령에서도 production·시세 disabled를 강제한다.

2026-11-02 `api-1.2.0-ada4794dbbd6`를 `/opt/service-contest/releases/` 아래 배치했다. `service-contest-api.service`의 `90-risk-lens-release.conf`가 새 WorkingDirectory를 가리키며 기존 Python 3.12.3 가상환경을 재사용한다. `/etc/service-contest.env`는 서버에서만 읽고 기존 `/opt/service-contest/app`은 복구용으로 보존했다. Nginx의 시세 차단도 유지한다. 임시 localhost:18000과 운영 localhost:8000, 외부 HTTPS에서 가상 현금흐름 산술·기존 계산·AI 5문제를 확인했다. 공개 PDF에는 Twelve Data 실데이터 또는 파생 수치를 넣지 않는다.

Android 1.2.0 서명 설치본은 운영 HTTPS에 직접 연결한다. ADB 포트 전달 없이 실기기 계산·AI 검사를 수행했으며 사용자가 USB 분리 후 3개월·6개월 현금흐름도 확인했다. 개인 서명 파일 두 개는 개발 PC에서 AES 7-Zip으로 암호화·복원 검증했고, Google Drive에는 이 암호화 파일만 백업한다. 서버 환경파일·TLS 인증서·사용자 재무정보는 이 백업 대상이 아니다.

## 7. MVP 이후 확장

운영 API는 [버전 배포 도구](../deploy/cloud/README.md)로 갱신한다. 별도 release 경로의 임시 서비스 검사 후 systemd drop-in으로 전환하고 실패 시 이전 설정을 복원한다. 2026-11-02 첫 전체 버전 배포와 외부 검증을 완료했다. 실제 장애를 일으키는 운영 롤백 훈련은 하지 않았으며 복구 도구의 회귀 테스트를 통과했다.

기간별 누적 이자는 현재 비영속 계산으로 구현했다. 계정, 영속 저장, 포트폴리오는 필요성이 확인되면 별도 아키텍처 결정으로 추가한다.
