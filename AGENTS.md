# Repository Guidelines

## 서비스 원칙

`리스크 렌즈`는 사용자의 금융상태와 종목의 과거 위험을 결합해 가정된 손실 충격을 설명하는 예방 서비스다. 투자 추천, 매수·매도 판단, 투자 가능 여부 판정, 미래 가격 예측을 생성하지 않는다. 과거 데이터는 미래 성과를 보장하지 않으며 출처·기준일·계산식을 결과에 표시한다.

## MVP 구조

- `apps/mobile/`: Flutter + Dart Android 앱
- `apps/api/`: FastAPI + Python 계산 API
- `docs/API_CONTRACT.md`: 모든 요청·응답 필드의 기준
- `docs/`: 제품, 흐름, 아키텍처, 데이터 모델, 로드맵
- `output/`: 공모전 제출용 PDF·영상 등 생성 결과물

코드는 `financial-health`, `market-risk`, `stress-test`, `combined-report` Vertical Slice로 나눈다. 각 Slice는 UI, API, 계산/연동, 테스트를 함께 소유한다. MVP에는 데이터베이스, 로그인, 서버 이력 저장, 별도 계약 패키지를 추가하지 않는다.

## 공통 계약과 코딩 규칙

기존 API contract를 임의 변경하지 않는다. 변경이 필요하면 영향받는 네 Slice의 담당자에게 알리고 `API_CONTRACT.md`, 구현 타입, 테스트를 같은 PR에서 수정한다. 같은 개념을 다른 이름으로 다시 만들지 않는다. JSON 필드는 계약대로 `snake_case`를 사용한다.

Dart는 `dart format`을 적용하고 클래스·Widget은 `PascalCase`, 함수·일반 변수는 `lowerCamelCase`를 사용한다. API DTO 프로퍼티와 JSON 키는 계약의 `snake_case`를 그대로 유지한다. Python은 4칸 들여쓰기, 타입 힌트, `snake_case`를 사용한다. 금액은 정수 원(KRW) 또는 `Decimal`로 계산한다. 금융 계산은 I/O 없는 결정론적 함수로 작성한다.

새 dependency는 표준 기능이나 기존 dependency로 해결할 수 없을 때만 추가하고 PR에 이유를 적는다. 다른 feature 영역을 대규모로 refactoring하지 않는다.

미국 종목의 과거 위험은 서버에서 Twelve Data의 분할 조정 일별 USD 종가(배당 제외)와 ECB 참고 환율을 결합한 원화 가격으로 계산한다. Twelve Data Basic 사용 중에는 국내 종목 실제 시세를 제공하지 않는다. 환율 기준일과 제공 범위를 숨기지 않는다. 고정 Stress Test의 주가·환율 충격만 결합하고 원화 기준 과거 MDD에는 환율 충격을 중복 적용하지 않는다. GitHub Actions는 환율 소스 감시에만 사용하며 계산값을 Git에 저장하지 않는다.

## AI·보안 규칙

LLM에는 이름, 재무 원본 전체, 인증정보를 보내지 않는다. 검증 완료된 최소 계산 결과만 전달하며 LLM이 숫자를 생성·수정하거나 투자 행동을 권고하게 하지 않는다. 외부 주가/LLM API 키는 FastAPI 서버 환경변수로만 주입하고 모바일 코드, 로그, Git에 넣지 않는다.

Twelve Data Basic은 비공개 심사 시연 범위에서만 사용한다. 공개 API에 종목 데이터를 노출하거나 공개 PDF에 Twelve Data 실데이터 및 파생 수치를 넣지 않는다. 공개 자료에는 명확히 표시한 가상 예시값을 사용하며, 외부 공개가 필요하면 제공자의 별도 이용 권한을 먼저 확인한다.

운영 API는 Naver Cloud의 단일 FastAPI 서버에 배포되어 있다. 배포 주소·구조가 바뀌면 `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`를 같은 변경에서 갱신한다. `/etc/service-contest.env`, 인증서, SSH 키와 실제 secret은 저장소에 복사하지 않는다.

## 테스트와 협업

계산식 변경 시 unit test를 반드시 함께 수정하고 정상값, 0인 분모, 100% 손실, 결측 시세를 검증한다. Python은 `pytest`와 Ruff, Flutter는 `flutter test`와 `flutter analyze`를 사용한다. 모바일은 `apps/mobile`에서 `flutter run`, API는 저장소 루트에서 `python -m uvicorn app.main:app --app-dir apps/api --reload`로 실행한다.

브랜치는 `feature/<slice>-<topic>` 형식, 커밋은 `feat: add mdd impact result` 같은 Conventional Commits를 사용한다. PR은 한 Slice와 한 목적만 담고 완료 조건, 테스트 결과, UI 변경 스크린샷을 포함한다. Codex가 만든 변경은 작성자가 diff와 테스트 결과를 직접 검토한다.
