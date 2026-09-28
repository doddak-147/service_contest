# Naver Cloud 배포 가이드

## 운영 구성

- 공개 API: `https://service-contest-2026-api.duckdns.org`
- 서버: Naver Cloud Platform Ubuntu VM
- 애플리케이션: `/opt/service-contest`
- 프로세스: `service-contest-api.service`가 Uvicorn을 `127.0.0.1:8000`에서 실행
- 공개 진입점: Nginx가 80/443 요청을 FastAPI로 전달
- HTTPS: Let's Encrypt 인증서와 Certbot 자동 갱신
- 환경변수: `/etc/service-contest.env`

서버에는 데이터베이스, 로그인, 분석 이력 저장소를 두지 않는다. 모바일에는 공개 URL만 포함하며 주가·LLM API 키는 서버에만 저장한다.

## 네트워크와 보안

Naver Cloud ACG 인바운드는 다음만 허용한다.

- TCP 22: 팀이 사용하는 관리자 공인 IP `/32`
- TCP 80: `0.0.0.0/0` — 인증서 발급과 HTTPS 전환
- TCP 443: `0.0.0.0/0` — 앱 API 요청

Uvicorn의 8000 포트는 외부에 공개하지 않는다. `/etc/service-contest.env`는 Git, 모바일 앱, 로그에 복사하지 않으며 `root:service-contest`, 권한 `640`을 유지한다. DuckDNS 계정 토큰과 SSH 인증키도 저장소에 추가하지 않는다.

## 상태 확인

외부 PC에서 다음 명령으로 HTTPS와 API를 확인한다.

```powershell
Invoke-RestMethod https://service-contest-2026-api.duckdns.org/health
```

서버 장애 조사 시 SSH 접속 후 다음 순서로 확인한다.

```bash
systemctl status service-contest-api --no-pager
journalctl -u service-contest-api -n 100 --no-pager
systemctl status nginx --no-pager
nginx -t
curl http://127.0.0.1:8000/health
curl https://service-contest-2026-api.duckdns.org/health
```

로그를 공유하기 전 API 키, 사용자 재무정보, LLM 요청 본문이 없는지 확인한다.

## 서버 코드 갱신

배포 전 로컬에서 전체 검사를 통과시키고 변경사항을 Git에 기록한다. 현재 수동 배포 방식에서는 `apps/api/app`과 `requirements.txt`만 서버로 전송한다. 삭제된 서버 파일이 있다면 별도로 확인해 정리하고, 다른 경로를 덮어쓰지 않는다.

Windows PowerShell:

```powershell
scp -r .\apps\api\app\* root@<SERVER_IP>:/opt/service-contest/app/
scp .\apps\api\requirements.txt root@<SERVER_IP>:/opt/service-contest/requirements.txt
ssh root@<SERVER_IP>
```

서버:

```bash
cd /opt/service-contest
source .venv/bin/activate
python -m pip install -r requirements.txt
systemctl restart service-contest-api
systemctl is-active service-contest-api
curl https://service-contest-2026-api.duckdns.org/health
```

환경변수를 변경했다면 `/etc/service-contest.env`만 서버에서 수정하고 서비스를 재시작한다. 실제 secret 값은 문서나 명령 기록에 남기지 않는다.

## HTTPS 갱신 확인

```bash
systemctl is-active certbot.timer
certbot renew --dry-run
```

갱신 실패 시 DNS가 현재 Naver Cloud 공인 IP를 가리키는지, ACG의 80/443 포트와 Nginx 상태를 먼저 확인한다.

## 모바일 시연 빌드

```powershell
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=https://service-contest-2026-api.duckdns.org
```

APK 경로는 `build/app/outputs/flutter-apk/app-release.apk`이다. 설치 후 시작 화면의 `서버 상태: 연결됨`을 확인하고 금융체력, Stress Test, 과거 위험, 결합 Report, AI 설명을 차례로 점검한다. 현재 APK는 내부 시연용 debug 인증서로 서명되며 Play Store 배포 전에는 별도의 release keystore가 필요하다.
