# 공개 종목 API 임시 차단

`market-data-gate.conf`를 공개 HTTPS `server` 블록에 포함한다. 이 설정은 종목 검색, 과거 위험·가격 이력, 결합 분석의 공개 요청에 JSON 503을 반환한다. `/health`, 금융체력, 고정 Stress Test, 현금흐름, 위험 이해 문제, 쉬운 설명은 계속 FastAPI로 전달한다. Twelve Data Basic을 공개 서버에서 켜지 않는다.

2026-11-02 최신 API의 [버전 배포](../cloud/README.md) 후에도 이 차단을 유지했다. 애플리케이션은 production·시세 disabled로 실행하며 외부 HTTPS에서 검색·가격 이력·결합 분석의 JSON 503과 no-store를 다시 확인했다.

2026-11-01 운영 서버에 적용했다. 적용 전 사이트 설정은 `/etc/nginx/sites-available/service-contest-api.bak-20261101`에 백업했다. `nginx -t`와 reload가 성공했고, 외부 요청에서 종목 세 경로는 503 `MARKET_DATA_UNAVAILABLE`, `/health`·금융체력·고정 Stress Test는 200, 설명 API의 잘못된 입력은 422로 확인했다. Android 릴리스 설치본에서도 검색 차단 사유가 표시됐다.

1. `/etc/nginx/sites-available/service-contest-api`를 백업한다.
2. `market-data-gate.conf`를 서버의 `/etc/nginx/snippets/market-data-gate.conf`로 복사한다.
3. 공개 HTTPS `server { ... }` 안에 `include /etc/nginx/snippets/market-data-gate.conf;`를 한 줄 추가한다. HTTP가 FastAPI로 직접 프록시되는 설정이라면 해당 HTTP `server` 블록에도 포함한다. HTTP가 HTTPS로만 리디렉션한다면 HTTPS 블록에만 포함한다.
4. `nginx -t` 성공 후 `systemctl reload nginx`를 실행한다.
5. 아래 요청을 외부 PC에서 확인한다. 종목 세 경로는 모두 HTTP 503과 `MARKET_DATA_UNAVAILABLE` JSON, `/health`는 HTTP 200이어야 한다.

```text
GET /api/v1/instruments/search
GET /api/v1/market-risk/NASDAQ/AAPL?start_date=invalid
POST /api/v1/combined-analyses  (JSON {})
GET /health
```

검증 실패 시 백업한 Nginx 사이트 파일을 복원하고 `nginx -t` 성공 후 다시 `systemctl reload nginx`를 실행한다. 공개 종목 API의 재개는 데이터 이용 권한과 접근 통제를 확인한 뒤 별도로 결정한다.
