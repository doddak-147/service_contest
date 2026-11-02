# 리스크 렌즈 Flutter 모바일 앱

Android용 Flutter/Dart 앱입니다. 실행과 환경 설정은 저장소 루트의 [README.md](../../README.md)를 따릅니다. 앱은 `--dart-define=API_BASE_URL=...`로 FastAPI 주소만 전달받으며 secret을 포함하지 않습니다.

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

연결된 Android 기기에서 핵심 흐름 자동 테스트를 실행할 수 있습니다. 테스트 API 응답을 사용하므로 실제 API 키나 운영 서버에 접근하지 않습니다.

```powershell
flutter test integration_test/core_flow_test.dart -d <DEVICE_ID>
```

USB 실기기에서 배포 서버를 사용하려면 다음과 같이 실행합니다.

```powershell
flutter devices
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=https://service-contest-2026-api.duckdns.org
```

FastAPI 요청·응답 DTO는 [API_CONTRACT.md](../../docs/API_CONTRACT.md)의 필드명과 타입을 그대로 사용합니다.

현재 서명 설치본은 1.2.0(`versionCode=4`)입니다. 운영 HTTPS에서는 금융체력·고정 Stress Test·현금흐름/생활 충격·A/B·AI 5문제를 제공합니다. 실제 미국 주식·ETF의 과거 위험·가격 그래프·결합 Report는 비공개 로컬 시연에서만 사용합니다. 운영 설치본에는 PC 서버나 USB 연결이 필요하지 않습니다. 설치·백업은 [RELEASE_APK.md](../../docs/RELEASE_APK.md), 환경별 절차는 [DEMO_RUNBOOK.md](../../docs/DEMO_RUNBOOK.md)를 따릅니다.

# 공개 자료용 오프라인 체험

홈의 `오프라인 체험 · 완전 가상`은 미리 작성한 가상기업 A와 가상 재무 사례를 3단계로 보여줍니다. 이 화면에서는 시장 데이터·환율·AI·분석 API를 호출하지 않으며, 네트워크가 끊겨도 사용할 수 있습니다. 결과는 실제 분석이 아니라 설명용 고정 예시입니다.

`가상 예시로 체험`은 **재무 입력만** 가상이고 실제 시세가 표시될 수 있습니다. 공개 가능성이 있는 PDF 캡처 또는 공개 영상에는 오프라인 체험 화면만 사용하세요. 비공개 심사용 실제 데이터 시연 영상도 PDF에 삽입하거나 공개 링크로 연결하면 공개물이 되므로 별도로 관리해야 합니다. Twelve Data 출처 표기만으로 외부 표시 권한이 생기지는 않습니다.
