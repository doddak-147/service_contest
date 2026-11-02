# Android 설치본

## 로컬 서명 자료

Android release 빌드는 `apps/mobile/android/key.properties`에 지정된 개인 서명 키를 사용한다. 이 파일과 키 저장소, 비밀번호는 Git에 넣지 않는다. 현재 개발 PC의 키 저장소는 `Documents/RiskLensSigning/risk-lens-release.p12`에 있다. 두 파일을 안전한 별도 저장 위치에 함께 백업해야 같은 앱 ID의 다음 버전을 업데이트할 수 있다. 키를 잃으면 기존 설치본을 같은 서명으로 업데이트할 수 없다.

## 빌드와 검증

저장소 루트의 PowerShell에서 실행한다.

```powershell
.\scripts\build-release-apk.ps1
```

스크립트는 HTTPS 운영 주소를 앱에 설정하고, release APK를 빌드하고, Android `apksigner`로 서명을 검증한 뒤 `pubspec.yaml`의 버전명에 맞춰 `output/apk/RiskLens-Android-1.2.0.apk`에 복사한다. 출력된 인증서 SHA-256 지문과 APK SHA-256 해시는 설치본 확인용으로 보관한다. APK는 Git에 추가하지 않는다. Flutter와 Android 도구는 PATH 또는 로컬 SDK 설정에서 찾는다.

USB 연결 휴대폰에 기존 디버그 서명 앱이 있으면 서명 불일치로 덮어쓰기가 실패한다. 이 경우 기존 앱을 제거한 다음 설치한다. 이 앱은 로그인이나 저장된 분석 이력이 없지만, 실행 중 입력한 값은 제거 시 사라진다.

```powershell
adb uninstall com.financialshock.financial_shock_preview
adb install .\output\apk\RiskLens-Android-1.2.0.apk
```

설치 후 앱에서 서버 연결, 공개용 완전 가상 체험, 접근 불가 시 오류 표시를 확인한다. Twelve Data Basic을 사용하는 실제 시세 기능과 APK는 제공자에게 외부 표시·배포 권한을 받기 전에는 제삼자에게 배포하지 않는다.

2026-11-02 1.2.0(`versionCode=4`) 서명 APK를 `SM S906N`에 설치했다. APK SHA-256은 `FD89311822601947991DE3D697B741D4BBFDD0B917912FFF740A04097902C6F9`, 서명 인증서 SHA-256은 `d9d2eead74b3e127fe8231ac8117567ec34d16fa68aa653ef9444a20792d4d54`다. USB 포트 전달 없이 운영 HTTPS 계산·AI 연결의 실기기 검사를 통과했고 릴리스 앱의 홈 연결·직접 입력 현금흐름도 확인했다. 이후 사용자가 USB를 물리적으로 분리하고 3개월·6개월 결과가 정상 출력됨을 확인했다. 인터넷 연결은 사용하는 온라인 계산이다.

## 서명 파일 백업

Google Drive에는 파일 목록도 암호화한 7-Zip 아카이브만 올린다. 저장소 루트의 PC PowerShell에서 다음을 실행한다. 비밀번호는 7-Zip이 요청하는 터미널에 직접 입력하며 채팅·스크립트 인수에 넣지 않는다. 선택한 암호는 별도의 비밀번호 관리 도구에 보관한다.

```powershell
.\scripts\backup-signing-encrypted.ps1
```

두 파일을 직접 읽어 암호화하며 평문 복사본을 별도 백업으로 만들지 않는다. 잘못된 암호로는 파일명도 읽을 수 없는지 확인하고, 사용자 전용 임시 폴더에 실제로 복원한 뒤 원본과 SHA-256을 대조한다. 정상 검증 후 임시 평문 두 파일을 지운다. 결과는 `Documents/RiskLensBackups`의 `.7z`와 해시 파일이며 Git 밖에 둔다. 가상 서명 파일에 이어 2026-11-02 실제 서명 파일 두 개로 암호화·복원·일치 검사를 통과했다. 암호는 사용자 터미널의 7-Zip에 직접 입력했으며 채팅이나 코드에 보관하지 않았다.

현재 로컬 백업은 `RiskLens-signing-20261102-185002-f0e44edc.7z`(3,855바이트)이며 SHA-256은 `2BCD0C9636E3DB964270DB63446547808A0F1F10B91BB73944014E1A445F2CF9`다. 잘못된 암호로 파일명을 열 수 없었고 실제 복원된 두 파일은 원본과 일치했다. 남은 임시 복원 폴더는 0개다. 같은 날 사용자가 Google Drive 업로드 후 다시 다운로드했으며 PC `Downloads`의 파일은 크기와 SHA-256이 원본과 일치했다. 이미 복원 검사한 아카이브와 동일하므로 암호 입력·압축 해제를 반복하지 않았다. Drive 계정의 공유 권한을 자동화 도구로 직접 점검한 것은 아니다.

암호화 파일을 비공개 Google Drive에 올린 뒤 다시 다운로드해 아래와 같이 검증한다. 경로와 해시는 실제 파일과 최초 출력값으로 바꾼다. 업로드·다운로드·동일 해시·복원 일치까지 확인해야 외부 백업 완료로 기록한다.

Drive의 미리보기나 Windows 파일 연결은 백업에 필요하지 않다. `.7z`를 압축된 상태로 업로드·다운로드하며 Drive에서 파일을 오른쪽 클릭해 다운로드한다. 내려받은 파일의 SHA-256이 이미 복원 검사한 원본 아카이브와 같으면 동일한 백업임을 확인할 수 있다. 암호화 파일의 미리보기를 위해 다른 클라우드 앱을 연결할 필요는 없다.

```powershell
.\scripts\backup-signing-encrypted.ps1 -VerifyOnly -Archive 'C:\Users\Administrator\Downloads\RiskLens-signing-example.7z' -ExpectedSha256 '<최초 출력 SHA256>'
```

초기 2026-11-01에는 두 파일의 존재만 확인했고 기능 확장 때문에 외부 백업을 미뤘다. 현재 진행 상태는 위 기록을 따른다. 외장 USB나 암호화된 직접 경로를 대안으로 사용할 경우 저장소 루트에서 다음을 실행한다. `E:\RiskLensBackup`은 준비한 실제 저장 위치로 바꾼다.

```powershell
.\scripts\backup-signing.ps1 -Destination 'E:\RiskLensBackup'
```

스크립트는 새로운 날짜별 하위 폴더에 서명 설정과 키 저장소를 함께 복사하고 SHA-256으로 원본과 일치를 검사한다. 저장소 안이나 심볼릭 링크·정션 경로에는 복사하지 않는다. 키와 비밀번호는 출력하지 않는다. 이 백업은 원본 파일을 포함하므로 암호화된 저장 위치를 사용한다. 현재 위치의 존재만 확인하려면 `-VerifyOnly`를 사용하며, 이 확인은 백업 완료를 의미하지 않는다.

## PC 교체 후 복구

1. 비공개 Drive의 `.7z`를 내려받고 기록한 아카이브 SHA-256과 대조한다.
2. 7-Zip으로 로컬의 비공개 폴더에 압축을 풀면서 별도로 보관한 백업 암호를 직접 입력한다. 암호는 백업 파일과 구분해 보관한다.
3. 키 저장소를 `Documents/RiskLensSigning/risk-lens-release.p12`에, `key.properties`를 복원한 저장소의 `apps/mobile/android/key.properties`에 둔다. PC 경로가 다르면 `storeFile`만 새 키 저장소 경로로 조정한다.
4. `build-release-apk.ps1`로 빌드하고 위 인증서 SHA-256과 같은지 확인한다. 두 복원 파일과 암호는 Git에 넣지 않는다.

기존 원본과 비교하는 `-VerifyOnly`는 현재 PC에서 백업을 검사하기 위한 모드다. 원본이 없는 새 PC에서 파일을 복구하는 절차와 구분한다.
