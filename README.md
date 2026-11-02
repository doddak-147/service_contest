# 리스크 렌즈 (Risk Lens)

차입투자를 실행하기 전에 개인 재무상태와 종목의 과거 위험을 결합해 금융 충격을 확인하는 Android 앱입니다. 투자 추천, 매수·매도 판단, 투자 가능 여부 판정 또는 미래 주가 예측은 제공하지 않습니다.

## 현재 상태

2026-11-02 기준 최신 API의 클라우드 배포·외부 HTTPS 검사·Android 설치본 검증을 마쳤습니다. 사용자는 USB 분리 후 3개월·6개월 현금흐름 결과도 확인했습니다. 서명 파일은 로컬 암호화·실제 복원 검사를 통과했고, 사용자가 Google Drive에 업로드한 뒤 내려받은 파일의 SHA-256이 원본과 일치했습니다. 관련 Markdown 17개를 검토해 최신 제공 범위와 실행·배포·복구 절차를 정리했습니다. 완료 범위는 [QA 기록](docs/QA_REVIEW.md)에 구분해 남깁니다.

| 영역 | 구현 상태 |
|---|---|
| 모바일 | Flutter/Dart Android 앱, 실기기 전체 흐름 확인 완료 |
| 계산 API | FastAPI/Python 결정론적 계산 구현 완료 |
| 주가 데이터 | 로컬 소스는 Twelve Data 미국 상장 주식·ETF 일별 시세와 ECB 참고 환율을 결합한 원화 기준 과거 위험 분석. 국내 시세와 지수 자체는 현재 미지원 |
| 쉬운 설명 | OpenAI-compatible LLM 연결, 검증 실패 시 정적 template 대체 |
| 현금흐름·생활 충격 | 3·6·12개월, 이자·원금 상환·현금 잔액, 소득·생활비·금리 충격, 화면 내 A·B 비교 |
| 위험 이해 체험 | 8주제에서 한 번에 5문제, 정답·오답 표시, AI 제목·도입과 서버의 검증된 가상 계산 |
| 배포 | Naver Cloud + Nginx + HTTPS 운영 중 |
| 저장 | 로그인·DB·서버 분석 이력 없음 |

운영 상태는 <https://service-contest-2026-api.duckdns.org/health>에서 확인할 수 있습니다.
운영 release는 `api-1.2.0-ada4794dbbd6`이며 [버전 배포 절차](deploy/cloud/README.md)로 반영했습니다. 금융체력·고정 Stress Test·월별 현금흐름·AI 5문제는 외부 HTTPS에서 검증했습니다. 문제 API는 `source=llm`, 대체 사유 없음으로 응답했습니다. 운영 실행은 `APP_ENV=production`, `STOCK_DATA_PROVIDER=disabled`를 강제합니다. 종목 검색·과거 위험·가격 그래프·결합 분석은 기존 Nginx 차단을 유지해 JSON 503을 반환합니다. 소스 배포와 실제 시세 제공 재개는 다른 작업입니다.

| 사용 방식 | 사용할 수 있는 범위 |
| --- | --- |
| 운영 HTTPS 설치본 | 재무 계산, 고정 Stress Test, 직접 입력 현금흐름·생활 충격·A/B, AI 가상 문제 |
| 비공개 로컬 시연 | 위 기능과 Twelve Data 미국 주식·ETF 검색·과거 위험·가격 그래프·결합 Report |
| 완전 가상 오프라인 체험 | 실제 시세에서 유래하지 않은 고정 가상 재무·종목·그래프·현금흐름·자체 문제, 분석 API 무호출 |

1.2.0(`versionCode=4`) 서명 APK는 `output/apk/RiskLens-Android-1.2.0.apk`입니다. 입력칸 잘림과 스크롤 후 접힘을 수정하고 정답·오답 표시가 있는 5문제 체험을 반영했습니다. 비공개 시연은 [실행 절차](docs/DEMO_RUNBOOK.md), 설치본과 서명 백업은 [릴리스 안내](docs/RELEASE_APK.md), 구현·검증 이력은 [기능 확장 기록](docs/FEATURE_EXPANSION.md)을 따릅니다. 검토 브랜치는 `feature/foundation-learning-quiz`이며 `main` 병합은 별도 리뷰 대상입니다.

상세기획서는 사용자가 제공한 Word 양식에 맞춘 [작성본 DOC](output/documents/리스크렌즈_상세기획서_작성본.doc)와 [DOCX](output/documents/리스크렌즈_상세기획서_작성본.docx)를 준비했습니다. 원본 서식과 본문 글자 크기를 유지한 9쪽이며 [양식 본문](docs/contest/리스크렌즈_상세기획서_양식본문.md)에 내용이 있습니다. 원본은 보존했고 가상 화면·계산 예시만 사용했습니다. 홈페이지 제출은 하지 않았습니다. 이전 [7쪽 PDF 초안](output/pdf/리스크렌즈_상세기획서_초안.pdf)은 별도 검토 자료입니다.

## 프로젝트 구조

```text
apps/mobile/  Flutter + Dart Android 앱
apps/api/     FastAPI + Python 계산 API
docs/         제품 명세, API 계약, 아키텍처, 로드맵, 공모전 자료 기준
output/       공모전 제출용 PDF·시연 영상 등 생성 결과물
```

기능은 `financial-health`, `market-risk`, `stress-test`, `combined-report` Vertical Slice로 구성합니다. 필드명과 타입의 단일 기준은 [API_CONTRACT.md](docs/API_CONTRACT.md)입니다.

## 로컬 설치

필요한 환경은 Flutter 3.41/Dart 3.11 이상, Android SDK, Python 3.11 이상입니다. PowerShell에서 다음을 실행합니다.

```powershell
cd apps/mobile
flutter pub get
cd ../..

python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r apps/api/requirements-dev.txt
```

서버 설정은 프로세스 환경변수로 주입합니다. 종목 API 기본값은 `disabled`이며, `STOCK_DATA_PROVIDER=twelve`와 `TWELVE_DATA_API_KEY`를 함께 설정해야 미국 상장 주식·ETF 조회가 동작합니다. Basic 요금제의 비공개 시연에만 사용하며 현재 `APP_ENV=production`에서는 Twelve 설정을 거부합니다. 공개 서버에는 접근 제한 전까지 적용하지 않습니다. OpenAI 연결 시에는 `LLM_PROVIDER`, `LLM_API_URL`, `LLM_API_KEY`, `LLM_MODEL`을 설정합니다. 실제 키는 Git과 모바일 코드에 넣지 않습니다.

실기기 비공개 시연에서 주가 데이터와 AI 설명을 함께 켜려면 기존 API를 `Ctrl+C`로 중지하고 저장소 루트에서 아래 스크립트를 실행합니다. 각 안내가 나온 **다음** 해당 API 키 문자열만 클립보드에 복사하고 터미널에서 붙여넣지 않은 채 Enter를 누릅니다. 스크립트가 클립보드에서 키를 읽은 뒤 비우며, 키는 파일·명령 기록에 저장하지 않고 서버가 끝나면 프로세스 환경변수에서 제거합니다. OpenAI API 사용량은 별도 과금될 수 있습니다.

```powershell
.\scripts\start-local-api.ps1
```

이 스크립트는 개발 모드의 로컬 `127.0.0.1:8000` 서버만 시작합니다. 두 번째 PC 터미널에서 `.\scripts\run-private-demo.ps1`을 실행하면 도구·휴대폰·서버를 확인하고 USB 연결과 앱 실행을 수행합니다. 상세 순서는 [시연 실행 절차](docs/DEMO_RUNBOOK.md)를 따릅니다. AI가 설정되지 않거나 제공자 오류·안전성 검증 실패가 발생하면 API는 계산값을 유지하고 검증된 기본 설명과 사유를 반환합니다. 공개 Naver Cloud 서버에는 Twelve Data Basic을 연결하지 않습니다.

## 실행

로컬 API:

```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --app-dir apps/api --reload --host 127.0.0.1 --port 8000
```

Android 에뮬레이터는 기본적으로 `http://10.0.2.2:8000`을 사용합니다.

```powershell
cd apps/mobile
flutter run
```

USB 실기기에서 운영 API에 연결하려면 먼저 `flutter devices`로 기기 ID를 확인합니다.

```powershell
cd apps/mobile
flutter devices
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=https://service-contest-2026-api.duckdns.org
```

`API_BASE_URL`에는 공개 API 주소만 넣고 API 키나 비밀번호를 넣지 않습니다.

## 주요 사용자 흐름

1. 시작 화면에서 `가상 예시로 체험` 또는 `내 값으로 시작`을 고르고 서버 연결 상태와 서비스 한계를 확인합니다. 예시는 재무값만 가상이며 종목 시세는 실제 데이터일 수 있습니다.
2. 재무정보를 입력해 월 잉여현금, 비상자금 버팀 기간, 차입 비율을 계산합니다. 내 값으로 시작하면 입력칸은 비어 있습니다.
3. 고정 가격 충격 Stress Test와 자기자본을 동일하게 둔 차입 없음/차입 있음 비교를 하거나, 미국 상장 주식·ETF를 선택해 과거 수익률·변동성·MDD를 확인합니다. SPY·QQQ ETF는 빠른 선택이 가능하고, 영어 이름·티커와 일부 주요 종목의 한글 별칭으로 검색할 수 있습니다. 지수 자체는 제외합니다. 미국 종목은 최근 3개월을 조회하며 날짜별 ECB 참고 환율로 환산한 원화 기준 지표를 표시합니다. 미국 거래소 현지 당일의 미확정 일봉은 분석에서 제외합니다. ETF의 배당·분배금은 포함하지 않으며 ETF 가격을 추종 지수의 가격과 동일하게 취급하지 않습니다.
4. 재무정보와 종목 MDD를 결합한 Report 상단에서 손실액, 하락 후 투자금, 유지되는 차입 원금을 먼저 보고 아래에서 자기자본·비상자금·생활비 대비 충격을 확인합니다.
5. 계산된 값만 전달받은 AI 또는 검증된 template의 쉬운 설명을 확인합니다.

금액 입력은 천 단위 쉼표로 표시하고, 연이율은 앱에서 `%`로 입력한 뒤 계약의 소수 단위로 전송합니다(예: `6` → `0.06`).
미국 종목에서 Stress Test로 이동하면 주가와 원/달러 환율 충격을 따로 선택할 수 있습니다. 과거 MDD는 이미 원화 환산 결과이므로 환율 충격을 다시 더하지 않습니다. ECB 환율은 실제 환전가·수수료가 아닌 참고 기준값이고, Twelve Data 일별 종가는 분할 조정·배당 제외 기준입니다. `.github/workflows/fx-source-check.yml`은 평일에 환율 소스 가용성만 점검하며 환율 값을 Git에 저장하거나 앱으로 배포하지 않습니다.

Twelve Data 측 답변에 따라 Basic 계정은 비공개 심사 시연에만 사용합니다. 수상 후 공개될 수 있는 PDF에는 실제 Twelve Data 시세 및 그 파생 결과를 넣지 않고, 명확히 표시한 가상 예시값을 사용합니다. 앱 또는 종목 API를 외부에 공개 배포하려면 별도 이용 권한과 접근 통제를 확인해야 합니다.

## 품질 검사

```powershell
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test

cd ../api
python -m ruff check .
python -m pytest

cd ../..
python -m ruff check --config apps/api/pyproject.toml scripts
python -m ruff check --config apps/api/pyproject.toml deploy/cloud
python -m pytest -c apps/api/pyproject.toml scripts/tests
```

개발 전에는 [AGENTS.md](AGENTS.md), [PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [API_CONTRACT.md](docs/API_CONTRACT.md)를 확인합니다. 주가 데이터 검산 기준은 [MARKET_DATA_VALIDATION.md](docs/MARKET_DATA_VALIDATION.md)를 따릅니다.

## 공모전 참고자료

2026-11-02 공개용 7쪽 PDF·1분 13초 영상, 심사용 6쪽 PDF·1분 13초 영상, 메일 원본 증빙을 포함한 내부 안내서 6쪽을 만들었습니다. [자료 구성과 읽는 순서](docs/contest/리스크렌즈_참고자료_구성.md)를 참고하세요. PDF 마지막 쪽에 영상 파일을 첨부하고 별도 MP4도 동봉합니다.

제출용 ZIP은 로컬 `output/submission/리스크렌즈_참고자료_제출용.zip`과 바탕화면 `공모전 용` 폴더에 있습니다. 실제 시세에서 유래한 심사 자료·메일 증빙·전체 ZIP은 Git에서 제외하며, 공개용에는 독립된 가상 예시만 사용합니다. 홈페이지 제출은 진행하지 않았습니다.
