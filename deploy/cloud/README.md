# 운영 API 버전 배포

최신 API를 `/opt/service-contest/releases/api-1.2.0-<commit>`에 별도로 배치한다. 기존 `/opt/service-contest/app`과 서버 환경파일·인증서·키는 수정하거나 내려받지 않는다. 기존 Python 가상환경을 재사용하며 의존성을 자동 업그레이드하지 않는다.

PC PowerShell의 저장소 루트에서 실행한다.

```powershell
.\scripts\deploy-cloud.ps1
```

OpenSSH가 서버 비밀번호를 여러 번 요청할 수 있다. 비밀번호는 사용자가 해당 터미널에 직접 입력한다. 스크립트·명령 인수·로그·저장소에 저장하지 않는다. 패키지만 준비하려면 `-PrepareOnly`를 지정한다.

스크립트는 추적 중인 API Python 소스와 requirements만 패키징한다. SHA-256과 파일별 manifest를 검사하고 경로 탈출·중복 파일·심볼릭 링크·환경파일을 거부한다. 서버에서 root로 실행하는 `apply-release.py`는 다음 순서로 처리한다.

1. 기존 Nginx 구성과 Python 라이브러리 import를 검사한다.
2. localhost:18000에 임시 systemd 서비스를 실행한다. 기존 `/etc/service-contest.env`는 systemd가 직접 읽는다.
3. 가상 예시의 현금흐름·기존 계산·5문제 응답과 실제 시세 비활성화를 확인한다. AI 문구가 실패하면 계약대로 기본 문제로 대체하며 source와 사유만 출력한다.
4. `90-risk-lens-release.conf` drop-in만 백업·교체하고 운영 서비스를 재시작한다. `APP_ENV=production`, `STOCK_DATA_PROVIDER=disabled`를 실행 명령에서 강제한다.
5. 같은 검증을 운영 localhost:8000에서 반복한다. 실패하면 이전 drop-in을 복원하고 서비스를 다시 시작한다. 임시 서비스는 종료한다.

성공 시 출력되는 `Rollback: python3 ... --rollback ...` 명령을 서버 SSH 터미널에 보관한다. 수동 복구는 해당 배포의 drop-in이 현재와 일치할 때만 허용한다. 원본 앱과 이전 배포는 자동 삭제하지 않는다. `/tmp`의 실행 도구가 삭제되면 같은 도구를 다시 업로드한 뒤 `--rollback <release_id>`로 실행한다.

배포 후 외부 HTTPS와 Android 설치본 검증은 별도로 수행한다. 종목 검색·과거 위험·결합 분석에 대한 기존 Nginx 차단은 유지한다. 새 현금흐름·위험 이해 API만으로 실제 주가가 공개되지는 않는다.

## 확인한 운영 release

2026-11-02 `api-1.2.0-ada4794dbbd6`를 배포했다. 소스 commit은 `ada4794dbbd6f3c99018814d2f542f0500f27f55`, 패키지 SHA-256은 `5178e9f12d399e3c57484e0f3b27caf909401810d17312a5b918fabd6832ca43`다. 임시·운영 서비스 모두 현금흐름 산술·기존 Stress Test·시세 disabled·AI 5문제(`source=llm`, 대체 사유 없음)를 통과했다. 외부 HTTPS에서도 같은 계산과 종목 차단을 확인했다. 검증 범위는 [QA 기록](../../docs/QA_REVIEW.md)을 따른다.

이 배포의 복구 명령은 서버 SSH에서 실행한다.

```bash
python3 /tmp/risk-lens-5178e9f12d399e3c/apply-release.py --rollback api-1.2.0-ada4794dbbd6
```
