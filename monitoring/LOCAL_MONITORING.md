# 로컬 모니터링 스택 실행 가이드

## 구성 요소

| 컨테이너 | 역할 | 로컬 접근 주소 |
|---|---|---|
| `app-dev` | Spring Boot 앱 (loadtest 프로파일) | http://localhost:8080 |
| `prometheus` | 메트릭 수집 | http://localhost:9090 |
| `loki` | 로그 수집 | http://localhost:3100 |
| `promtail` | 도커 로그 → Loki 전송 | - |
| `grafana` | 대시보드 시각화 | http://localhost:3001 |

## 사전 요구사항

- Docker Desktop 실행 중
- `make` 명령어 사용 가능
- 프로젝트 루트에 `.env` 파일 존재

### `.env` 파일 설정

```bash
cp .env.example .env
```

`.env`에 아래 항목이 채워져 있어야 한다.

```
DB_URL=jdbc:postgresql://<host>:<port>/<db>
DB_USERNAME=...
DB_PASSWORD=...
GOOGLE_OAUTH_CLIENT_ID=...
```

> OCI 관련 설정이 없어도 로컬에서는 `APP_STORAGE_TYPE=local`로 동작한다.

## 실행

### 1. 앱 + 모니터링 스택 한번에 시작

```bash
make monitor-up
```

내부적으로 다음 두 compose 파일을 함께 실행한다.
- `docker/docker-compose.test.yml` — Spring Boot 앱
- `docker/monitoring/compose/docker-compose.monitoring.local.yml` — Prometheus / Loki / Promtail / Grafana

### 2. 정상 기동 확인

```bash
make monitor-logs
```

`app-dev` 컨테이너에서 `Started ... in ... seconds` 로그가 보이면 준비 완료.

Grafana에 접속해 datasource 연결 상태를 확인한다.
- 주소: http://localhost:3001
- ID/PW: `admin` / `admin`
- 좌측 메뉴 → Connections → Data sources → Prometheus, Loki 모두 **Connected** 상태인지 확인

## 부하 테스트 (k6)

### 기본 실행

```bash
make perf ENV=local DOMAIN=test PERF_SCENARIO=smoke-test
```

| 파라미터 | 설명 | 기본값 |
|---|---|---|
| `ENV` | 환경 (`local` \| `cloud`) | `local` |
| `DOMAIN` | 테스트 도메인 디렉토리 | `test` |
| `PERF_SCENARIO` | 스크립트 파일명 (`.js` 제외) | `smoke-test` |

스크립트 위치: `perf/k6/scripts/<DOMAIN>/<PERF_SCENARIO>.js`  
결과 저장 위치: `perf/results/<ENV>/<DOMAIN>/<PERF_SCENARIO>/`

### Grafana에서 결과 확인

k6 메트릭은 Prometheus remote write로 실시간 전송된다.  
Grafana → Explore → Prometheus 데이터소스에서 `k6_*` 메트릭을 조회하거나 대시보드를 추가해 확인한다.

## 종료

```bash
make monitor-down
```

## 네트워크 구조

```
[app-dev] ──────── app-network ─────── [promtail]
                                            │
                                            ▼
[prometheus] ── perf-network ──── [loki] [grafana]
```

- `app-network`: 앱 컨테이너와 promtail이 공유
- `perf-network`: 모니터링 컨테이너들이 공유, k6도 여기에 참여

## 트러블슈팅

### 앱이 뜨지 않는 경우

```bash
docker logs app-dev
```

- `Caused by: ... DB_URL` → `.env`에 DB 설정 확인
- `/root/.oci/config (No such file or directory)` → `.env`에 `APP_STORAGE_TYPE=local` 추가

### Prometheus가 앱 메트릭을 못 가져오는 경우

http://localhost:9090/targets 에서 `spring` job의 상태 확인.  
`app-dev` 컨테이너가 `app-network`에 있고 Prometheus도 같은 네트워크에 있어야 한다.

### Loki에 로그가 안 쌓이는 경우

Promtail이 Docker 소켓을 읽어야 하므로 `/var/run/docker.sock` 마운트가 필요하다.  
Docker Desktop → Settings → Advanced → "Allow the default Docker socket to be used" 활성화 여부 확인.
