# 금융 충격 미리보기

과도한 차입투자로 인한 금융 충격을 사용자가 투자 전에 확인하도록 돕는 모바일 서비스입니다. 투자 추천, 매수·매도 판단 또는 미래 주가 예측을 제공하지 않습니다.

모바일은 Flutter/Dart Android 앱, 금융 계산 API는 FastAPI/Python으로 구성합니다. 현재 Foundation과 차입투자 Stress Test가 구현되어 있으며 종목 검색, 주가 연동, MDD·변동성, AI 설명은 아직 구현하지 않았습니다.

## 프로젝트 구조

```text
apps/mobile/  Flutter + Dart Android 앱
apps/api/     FastAPI + Python 계산 API
docs/         제품 명세, API 계약, 아키텍처, 로드맵
```

## 사전 준비

- Flutter 3.41 이상과 Dart 3.11 이상
- Android Studio 또는 Android SDK, 에뮬레이터
- Python 3.11 이상

설치 상태는 `flutter doctor`로 확인합니다.

## 설치

PowerShell 기준:

```powershell
cd apps/mobile
flutter pub get
cd ../..

python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r apps/api/requirements-dev.txt
```

macOS/Linux에서는 가상환경을 `source .venv/bin/activate`로 활성화합니다.

## 실행

첫 번째 터미널에서 FastAPI를 실행합니다.

```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --app-dir apps/api --reload --host 0.0.0.0 --port 8000
```

두 번째 터미널에서 Android 에뮬레이터를 켠 뒤 앱을 실행합니다.

```powershell
cd apps/mobile
flutter run
```

Android 에뮬레이터에서는 기본 API 주소 `http://10.0.2.2:8000`을 사용합니다. 실물 기기는 개발 PC의 LAN IP를 전달해야 합니다.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

`API_BASE_URL`은 공개 서버 주소 전용이며 API 키나 비밀번호를 넣지 않습니다. 배포 빌드는 HTTPS 주소를 사용합니다.

## 기능 확인

앱 시작 화면이 `GET /health`를 호출해 서버 연결 상태를 표시합니다. `Stress Test 시작하기`에서 투자정보를 입력하고 `-10%`부터 `-50%`까지 선택하면 `POST /api/v1/stress-tests/analyze`의 서버 계산 결과를 표시합니다.

요청·응답 필드와 단위는 [docs/API_CONTRACT.md](docs/API_CONTRACT.md)를 따릅니다. 앱의 연이율 입력은 `%` 단위이며 요청 시 계약의 소수 단위로 변환됩니다(예: `6` → `0.06`).

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

개발 전에 [AGENTS.md](AGENTS.md)와 [docs/API_CONTRACT.md](docs/API_CONTRACT.md)를 확인하세요. API DTO와 JSON 필드는 계약의 `snake_case` 이름을 그대로 사용합니다.
