# 리스크 렌즈 Flutter 모바일 앱

Android용 Flutter/Dart 앱입니다. 실행과 환경 설정은 저장소 루트의 [README.md](../../README.md)를 따릅니다. 앱은 `--dart-define=API_BASE_URL=...`로 FastAPI 주소만 전달받으며 secret을 포함하지 않습니다.

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

USB 실기기에서 배포 서버를 사용하려면 다음과 같이 실행합니다.

```powershell
flutter devices
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=https://service-contest-2026-api.duckdns.org
```

FastAPI 요청·응답 DTO는 [API_CONTRACT.md](../../docs/API_CONTRACT.md)의 필드명과 타입을 그대로 사용합니다.
