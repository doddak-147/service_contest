# Repository Guidelines

## 서비스 원칙

이 앱은 사용자의 금융상태와 종목의 과거 위험을 결합해 가정된 손실 충격을 설명하는 예방 서비스다. 투자 추천, 매수·매도 판단, 투자 가능 여부 판정, 미래 가격 예측을 생성하지 않는다. 과거 데이터는 미래 성과를 보장하지 않으며 출처·기준일·계산식을 결과에 표시한다.

## MVP 구조

- `apps/mobile/`: Expo + React Native + TypeScript
- `apps/api/`: FastAPI + Python 계산 API
- `docs/API_CONTRACT.md`: 모든 요청·응답 필드의 기준
- `docs/`: 제품, 흐름, 아키텍처, 데이터 모델, 로드맵

코드는 `financial-health`, `market-risk`, `stress-test`, `combined-report` Vertical Slice로 나눈다. 각 Slice는 UI, API, 계산/연동, 테스트를 함께 소유한다. MVP에는 데이터베이스, 로그인, 서버 이력 저장, 별도 계약 패키지를 추가하지 않는다.

## 공통 계약과 코딩 규칙

기존 API contract를 임의 변경하지 않는다. 변경이 필요하면 영향받는 네 Slice의 담당자에게 알리고 `API_CONTRACT.md`, 구현 타입, 테스트를 같은 PR에서 수정한다. 같은 개념을 다른 이름으로 다시 만들지 않는다. JSON 필드는 계약대로 `snake_case`를 사용한다.

TypeScript는 `strict`, 2칸 들여쓰기, `PascalCase` 컴포넌트, `camelCase` 함수·변수를 사용한다. Python은 4칸 들여쓰기, 타입 힌트, `snake_case`를 사용한다. 금액은 정수 원(KRW) 또는 `Decimal`로 계산한다. 금융 계산은 I/O 없는 결정론적 함수로 작성한다.

새 dependency는 표준 기능이나 기존 dependency로 해결할 수 없을 때만 추가하고 PR에 이유를 적는다. 다른 feature 영역을 대규모로 refactoring하지 않는다.

## AI·보안 규칙

LLM에는 이름, 재무 원본 전체, 인증정보를 보내지 않는다. 검증 완료된 최소 계산 결과만 전달하며 LLM이 숫자를 생성·수정하거나 투자 행동을 권고하게 하지 않는다. 외부 주가/LLM API 키는 FastAPI 서버 환경변수로만 주입하고 모바일 코드, 로그, Git에 넣지 않는다.

## 테스트와 협업

계산식 변경 시 unit test를 반드시 함께 수정하고 정상값, 0인 분모, 100% 손실, 결측 시세를 검증한다. Python은 `pytest`와 Ruff, TypeScript는 ESLint를 사용한다. 프로젝트 초기화 후 루트에 `npm run dev:mobile`, `npm run dev:api`, `npm run lint`, `npm test`를 제공하되 설정 전에는 동작한다고 가정하지 않는다.

브랜치는 `feature/<slice>-<topic>` 형식, 커밋은 `feat: add mdd impact result` 같은 Conventional Commits를 사용한다. PR은 한 Slice와 한 목적만 담고 완료 조건, 테스트 결과, UI 변경 스크린샷을 포함한다. Codex가 만든 변경은 작성자가 diff와 테스트 결과를 직접 검토한다.
