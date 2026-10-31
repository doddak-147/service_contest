# Android 설치본

## 로컬 서명 자료

Android release 빌드는 `apps/mobile/android/key.properties`에 지정된 개인 서명 키를 사용한다. 이 파일과 키 저장소, 비밀번호는 Git에 넣지 않는다. 현재 개발 PC의 키 저장소는 `Documents/RiskLensSigning/risk-lens-release.p12`에 있다. 두 파일을 안전한 별도 저장 위치에 함께 백업해야 같은 앱 ID의 다음 버전을 업데이트할 수 있다. 키를 잃으면 기존 설치본을 같은 서명으로 업데이트할 수 없다.

## 빌드와 검증

저장소 루트의 PowerShell에서 실행한다.

```powershell
.\scripts\build-release-apk.ps1
```

스크립트는 HTTPS 운영 주소를 앱에 설정하고, release APK를 빌드하고, Android `apksigner`로 서명을 검증한 뒤 `output/apk/RiskLens-Android-1.0.0.apk`에 복사한다. 출력된 인증서 SHA-256 지문과 APK SHA-256 해시는 설치본 확인용으로 보관한다. APK는 Git에 추가하지 않는다.

USB 연결 휴대폰에 기존 디버그 서명 앱이 있으면 서명 불일치로 덮어쓰기가 실패한다. 이 경우 기존 앱을 제거한 다음 설치한다. 이 앱은 로그인이나 저장된 분석 이력이 없지만, 실행 중 입력한 값은 제거 시 사라진다.

```powershell
adb uninstall com.financialshock.financial_shock_preview
adb install .\output\apk\RiskLens-Android-1.0.0.apk
```

설치 후 앱에서 서버 연결, 공개용 완전 가상 체험, 접근 불가 시 오류 표시를 확인한다. Twelve Data Basic을 사용하는 실제 시세 기능과 APK는 제공자에게 외부 표시·배포 권한을 받기 전에는 제삼자에게 배포하지 않는다.
