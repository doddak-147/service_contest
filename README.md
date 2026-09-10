# 금융 충격 미리보기

과도한 차입투자로 인한 금융 충격을 사용자가 투자 전에 확인하도록 돕는 모바일 서비스입니다. 투자 추천, 매수·매도 판단 또는 미래 주가 예측을 제공하지 않습니다.

현재 단계는 Expo 모바일 앱과 FastAPI 서버를 연결하는 Foundation입니다. 금융 분석 기능은 아직 구현하지 않았습니다.

## 프로젝트 구조

```text
apps/mobile/  Expo + React Native + TypeScript
apps/api/     FastAPI + Python
docs/         제품 명세, API 계약, 아키텍처, 로드맵
```

## 사전 준비

- Node.js 22.13 이상과 npm
- Python 3.11 이상
- 모바일 확인용 Expo Go 또는 Android/iOS 에뮬레이터

## 설치

PowerShell 기준:

```powershell
npm install --prefix apps/mobile
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r apps/api/requirements-dev.txt
```

macOS/Linux에서는 가상환경을 `source .venv/bin/activate`로 활성화합니다.

## 환경변수

모바일은 `EXPO_PUBLIC_API_BASE_URL`을 사용합니다. Android 에뮬레이터는 기본값 `http://10.0.2.2:8000`, iOS 시뮬레이터는 `http://localhost:8000`을 사용하므로 별도 설정이 필요 없습니다.

실물 기기에서는 [apps/mobile/.env.example](apps/mobile/.env.example)을 `apps/mobile/.env.local`로 복사하고 개발 PC의 LAN IP로 변경합니다.

```env
EXPO_PUBLIC_API_BASE_URL=http://192.168.0.10:8000
```

`EXPO_PUBLIC_` 값은 앱에 포함되므로 secret을 넣으면 안 됩니다. 서버의 `APP_ENV`, `CORS_ORIGINS`는 필요할 때 프로세스 환경변수로 설정하며 키 목록은 [apps/api/.env.example](apps/api/.env.example)에 있습니다.

## 실행

가상환경을 활성화한 뒤 서로 다른 터미널에서 실행합니다.

```powershell
npm run dev:api
npm run dev:mobile
```

FastAPI는 `http://localhost:8000`, API 문서는 개발 환경에서 `http://localhost:8000/docs`에 열립니다. Expo 앱 시작 화면은 `GET /health`를 자동 호출하고 연결 성공 또는 실패를 표시합니다.

서버만 확인하려면 다음 명령을 사용합니다.

```powershell
Invoke-RestMethod http://localhost:8000/health
```

정상 응답은 `{"status":"ok"}`입니다.

## 품질 검사

```powershell
npm run lint
npm run typecheck
npm test
```

모든 검사를 순서대로 실행하려면 `npm run check`를 사용합니다.

## 문서 기준

개발 전에 [AGENTS.md](AGENTS.md)와 [docs/API_CONTRACT.md](docs/API_CONTRACT.md)를 확인하세요. Foundation의 `GET /health` 외 금융 API 계약은 이번 단계에서 구현하지 않습니다.
