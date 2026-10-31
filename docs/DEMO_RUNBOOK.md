# 시연 실행 절차

## 실행 방식

| 방식 | 연결 | 종목 데이터 |
| --- | --- | --- |
| 비공개 심사 시연 | 개발 PC 로컬 API + USB 연결 디버그 앱 | Twelve Data Basic + ECB, 비공개 범위 |
| 운영 서버 연결 설치본 | HTTPS Naver Cloud | 종목 API 중단 안내, 금융체력·고정 Stress Test 사용 |
| 완전 가상 체험 | 서버 연결 불필요 | 명시된 가상값, 실제 시세·환율·AI 요청 없음 |

공개될 수 있는 화면 자료에는 완전 가상 체험을 사용한다. 비공개 심사 시연은 제공자에게 받은 이용 범위에 따라 진행한다.

## 비공개 시연: PC 터미널 두 개

휴대폰을 USB로 연결하고 잠금을 해제한다. USB 디버깅 허용 팝업이 나타나면 휴대폰에서 허용한다. 아래 명령은 모두 PC PowerShell에서 실행한다.

첫 번째 터미널:

```powershell
Set-Location C:\Users\Administrator\Documents\GitHub\service_contest
.\scripts\start-local-api.ps1
```

Twelve Data 안내가 나온 다음 키 문자열만 메모장에서 Ctrl+C로 복사하고, 터미널로 돌아와 붙여넣지 않은 채 Enter를 누른다. OpenAI 안내에서도 해당 키를 같은 순서로 복사한다. 스크립트가 클립보드를 읽은 뒤 비운다. `Application startup complete`가 나오면 서버가 요청을 기다리는 정상 상태이며 이 터미널은 계속 열어 둔다.

두 번째 터미널:

```powershell
Set-Location C:\Users\Administrator\Documents\GitHub\service_contest
.\scripts\run-private-demo.ps1
```

스크립트가 Flutter·ADB 경로와 허용된 휴대폰 한 대를 찾고, 서버 상태를 확인한 뒤 USB 포트 전달과 앱 실행을 수행한다. 여러 기기가 있으면 `-DeviceId RFCT328Q92E`처럼 대상 ID를 지정한다. 도구 경로는 PATH 또는 `apps/mobile/android/local.properties`의 SDK 경로를 사용한다.

앱에서 서버 연결 → 가상 재무 예시 → 미국 주식·ETF 조회 → 과거 위험·원화 기준일 → Stress Test → 결합 결과·쉬운 설명 순서로 확인한다. 실제 개인정보를 시연에 입력할 필요는 없다. API 한도·AI 장애가 생기면 오류·기본 설명 사유를 확인하고 완전 가상 체험으로 진행할 수 있다.

두 번째 터미널에서 앱 실행을 종료하면 USB 포트 전달을 제거한다. 첫 번째 터미널은 Ctrl+C로 종료하며 프로세스의 API 키 환경변수를 제거한다. USB를 분리하면 로컬 API 시연 연결도 종료된다.

## 실행 전 도구 확인

```powershell
.\scripts\run-private-demo.ps1 -CheckOnly
```

이 명령은 Flutter·Android 도구·휴대폰 허용 상태를 확인한다. 서버나 앱을 시작하지 않는다. Python `.venv`, Flutter SDK, Android SDK가 삭제되었으면 복원한 뒤 실행한다.

## 운영 주소를 사용하는 설치본

```powershell
.\scripts\build-release-apk.ps1
```

현재 출력은 `output/apk/RiskLens-Android-1.0.1.apk`다. 운영 주소에는 공개 종목 데이터 차단이 적용되어 있다. 서명 파일 복원·설치 절차는 [RELEASE_APK.md](RELEASE_APK.md)를 따른다. 실제 키는 앱 빌드 옵션에 넣지 않는다.
