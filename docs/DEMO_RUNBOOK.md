# 시연 실행 절차

## 실행 방식

| 방식 | 연결 | 종목 데이터 |
| --- | --- | --- |
| 비공개 심사 시연 | 개발 PC 로컬 API + USB 연결 디버그 앱 | Twelve Data Basic + ECB, 비공개 범위 |
| 운영 서버 연결 설치본 | HTTPS Naver Cloud, USB/PC 서버 불필요 | 종목 API 중단 안내, 금융체력·고정 Stress Test·현금흐름/생활 충격·A/B·AI 가상 문제 |
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

Windows 클립보드 읽기가 실패하면 `.\scripts\start-local-api.ps1 -PasteKeys`로 실행한다. 이 방식에서는 각 숨김 입력창에 해당 키 문자열을 직접 붙여넣고 Enter를 누른다. OpenAI는 쉬운 설명에 사용한 기존 키를 그대로 사용한다. 키를 새로 발급할 필요는 없으며 채팅·소스코드·명령 문자열에 넣지 않는다.

두 번째 터미널:

```powershell
Set-Location C:\Users\Administrator\Documents\GitHub\service_contest
.\scripts\run-private-demo.ps1
```

스크립트가 Flutter·ADB 경로와 허용된 휴대폰 한 대를 찾고, 서버 상태를 확인한 뒤 USB 포트 전달과 앱 실행을 수행한다. 여러 기기가 있으면 `-DeviceId RFCT328Q92E`처럼 대상 ID를 지정한다. 도구 경로는 PATH 또는 `apps/mobile/android/local.properties`의 SDK 경로를 사용한다.

앱에서 서버 연결 → 가상 재무 예시 → 미국 주식·ETF 조회 → 과거 위험·원화 기준일 → Stress Test → 결합 결과·쉬운 설명 순서로 확인한다. 실제 개인정보를 시연에 입력할 필요는 없다. API 한도·AI 장애가 생기면 오류·기본 설명 사유를 확인하고 완전 가상 체험으로 진행할 수 있다.

추가 기능은 홈의 월별 현금흐름에서 3·6·12개월과 생활 충격을 고르고 계산한다. 결과를 A에 보관하고 조건을 바꿔 재계산한 결과를 B에 보관하면 입력 차이와 현금·이자 차이를 확인할 수 있다. 가격 그래프는 과거 위험 결과에서 별도로 요청한다. 위험 이해 체험은 서버 없이 가능하다. 공개 자료에는 `오프라인 체험 · 완전 가상`에서 진입한 가상 현금흐름·가격 그래프·이해 사례를 사용한다.

위험 이해 체험은 8개 주제에서 한 번에 5문제를 제공한다. 홈에서 진입한 뒤 `AI로 새 5문제 만들기`를 누르면 같은 로컬 OpenAI 설정을 사용한다. AI는 제목·도입을 구성하고 서버가 가상 수치와 정답을 계산한다. AI·연결 실패 시 자체 문제와 사유를 확인한다. 오프라인 체험의 문제는 서버·AI를 호출하지 않는다. 정답 확인 후 선택을 바꿀 수 없으며 다섯 문제 뒤 새 묶음을 시작한다.

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

현재 출력은 `output/apk/RiskLens-Android-1.2.0.apk`다. 2026-11-02 운영 서버에 현금흐름·AI 문제 API를 배포했고 공개 종목 데이터 차단은 유지한다. 이 설치본은 인터넷이 있으면 PC 서버·USB 없이 직접 입력 현금흐름과 AI 가상 문제를 사용할 수 있다. 인터넷이 없으면 완전 가상 체험과 자체 문제를 사용한다. 서버 연결 상태 확인과 선택한 기능의 API 호출을 구분한다. 서명 파일 복원·설치 절차는 [RELEASE_APK.md](RELEASE_APK.md)를 따른다. 실제 키는 앱 빌드 옵션에 넣지 않는다.

실제 확인 범위는 운영 HTTPS의 실기기 검사 4종과 릴리스 설치·홈 연결·가상 재무 예시 온라인 계산이다. 사용자는 USB 분리 후 3개월·6개월 결과가 정상임을 확인했다. 이는 인터넷을 사용한 운영 연결 검증이며 오프라인 모드를 의미하지 않는다.

운영 코드를 갱신할 때는 [버전 배포 절차](../deploy/cloud/README.md)를 따른다. 실패 시 출력된 rollback 명령을 서버 SSH 터미널에서 사용한다. API 키·환경파일을 개발 PC나 Google Drive로 복사하지 않는다.
