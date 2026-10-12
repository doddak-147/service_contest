# 리스크 렌즈 (Risk Lens)

차입투자를 실행하기 전에 개인 재무상태와 종목의 과거 위험을 결합해 금융 충격을 확인하는 Android 앱입니다. 투자 추천, 매수·매도 판단, 투자 가능 여부 판정 또는 미래 주가 예측은 제공하지 않습니다.

## 현재 상태

| 영역 | 구현 상태 |
|---|---|
| 모바일 | Flutter/Dart Android 앱, 실기기 전체 흐름 확인 완료 |
| 계산 API | FastAPI/Python 결정론적 계산 구현 완료 |
| 주가 데이터 | 로컬 소스는 Twelve Data 미국 주식 일별 시세와 ECB 참고 환율을 결합한 원화 기준 과거 위험 분석. 국내 시세는 현재 미지원 |
| 쉬운 설명 | OpenAI-compatible LLM 연결, 검증 실패 시 정적 template 대체 |
| 배포 | Naver Cloud + Nginx + HTTPS 운영 중 |
| 저장 | 로그인·DB·서버 분석 이력 없음 |

운영 상태는 <https://service-contest-2026-api.duckdns.org/health>에서 확인할 수 있습니다.
Twelve Data 연동은 현재 저장소 소스에만 반영되어 있으며 운영 서버에는 배포되지 않았습니다. 운영 서버는 여전히 이전 버전이므로 종목 분석의 데이터 출처를 혼동하지 마세요. 로컬 테스트 통과만으로 운영 반영을 뜻하지 않습니다.

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

서버 설정은 프로세스 환경변수로 주입합니다. 종목 API 기본값은 `disabled`이며, `STOCK_DATA_PROVIDER=twelve`와 `TWELVE_DATA_API_KEY`를 함께 설정해야 미국 주식 조회가 동작합니다. Basic 요금제의 비공개 시연에만 사용하며 현재 `APP_ENV=production`에서는 Twelve 설정을 거부합니다. 공개 서버에는 접근 제한 전까지 적용하지 않습니다. OpenAI 연결 시에는 `LLM_PROVIDER`, `LLM_API_URL`, `LLM_API_KEY`, `LLM_MODEL`을 설정합니다. 실제 키는 Git과 모바일 코드에 넣지 않습니다.

로컬 PowerShell에서 API 키를 명령 기록에 남기지 않고 한 터미널 세션에만 설정하려면 다음을 실행합니다. 키는 화면에 표시되지 않으며 같은 터미널에서 API를 시작해야 합니다.

```powershell
$tdSecureKey = Read-Host 'Twelve Data API key' -AsSecureString
$env:TWELVE_DATA_API_KEY = [System.Net.NetworkCredential]::new('', $tdSecureKey).Password
$env:STOCK_DATA_PROVIDER = 'twelve'
Remove-Variable tdSecureKey
```

## 실행

로컬 API:

```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --app-dir apps/api --reload --host 0.0.0.0 --port 8000
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

1. 시작 화면에서 서버 연결 상태와 서비스 한계를 확인합니다.
2. 재무정보를 입력해 월 잉여현금, 비상자금 버팀 기간, 차입 비율을 계산합니다.
3. 고정 가격 충격 Stress Test를 비교하거나 미국 종목을 선택해 과거 수익률·변동성·MDD를 확인합니다. 미국 종목은 최근 3개월을 조회하며 날짜별 ECB 참고 환율로 환산한 원화 기준 지표를 표시합니다.
4. 재무정보와 종목 MDD를 결합한 Report에서 자기자본·비상자금·생활비 대비 충격을 확인합니다.
5. 계산된 값만 전달받은 AI 또는 검증된 template의 쉬운 설명을 확인합니다.

금액 입력은 천 단위 쉼표로 표시하고, 연이율은 앱에서 `%`로 입력한 뒤 계약의 소수 단위로 전송합니다(예: `6` → `0.06`).
미국 종목에서 Stress Test로 이동하면 주가와 원/달러 환율 충격을 따로 선택할 수 있습니다. 과거 MDD는 이미 원화 환산 결과이므로 환율 충격을 다시 더하지 않습니다. ECB 환율은 실제 환전가·수수료가 아닌 참고 기준값이고, Twelve Data 일별 종가는 분할 조정·배당 제외 기준입니다. `.github/workflows/fx-source-check.yml`은 평일에 환율 소스 가용성만 점검하며 환율 값을 Git에 저장하거나 앱으로 배포하지 않습니다.

Twelve Data 측 답변에 따라 Basic 계정은 비공개 심사 시연에만 사용합니다. 수상 후 공개될 수 있는 PDF에는 실제 Twelve Data 시세 및 그 파생 결과를 넣지 않고, 명확히 표시한 가상 예시값을 사용합니다. 앱 또는 종목 API를 외부에 공개 배포하려면 별도 이용 권한과 접근 통제를 확인해야 합니다.

## 품질 검사

```powershell
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd ../..
python -m ruff check apps/api
python -m pytest -c apps/api/pyproject.toml apps/api/tests
```

개발 전에는 [AGENTS.md](AGENTS.md), [PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [API_CONTRACT.md](docs/API_CONTRACT.md)를 확인합니다. 주가 데이터 검산 기준은 [MARKET_DATA_VALIDATION.md](docs/MARKET_DATA_VALIDATION.md)를 따릅니다.
