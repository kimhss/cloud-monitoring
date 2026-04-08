# 클라우드 모니터링 스택 실행 가이드

## 구성 요소

| 컨테이너 | 역할 | 접근 주소 |
|---|---|---|
| `app-dev` | Spring Boot 앱 (별도 배포) | `http://<SERVER_IP>:8080` |
| `prometheus-cloud` | 메트릭 수집 | `http://<SERVER_IP>:9090` |
| `loki-cloud` | 로그 수집 | `http://<SERVER_IP>:3100` |
| `promtail-cloud` | 도커 로그 → Loki 전송 | - |
| `grafana-cloud` | 대시보드 시각화 | `http://<SERVER_IP>:3000` |

> 로컬과 달리 모든 컨테이너가 **같은 서버**에서 실행된다. 네트워크는 외부에서 미리 생성되어 있어야 한다.

## 사전 요구사항

### 서버에 프로젝트 파일 준비

compose 파일이 볼륨 마운트에 `${PWD}/docker/monitoring/...` 경로를 사용하므로,  
**서버에 프로젝트 전체가 있어야 한다.**

```bash
git clone https://github.com/prgrms-be-devcourse/NBE8-10-final-Team04.git
cd NBE8-10-final-Team04
```

이후 모든 명령은 이 디렉토리(`NBE8-10-final-Team04/`)에서 실행한다.

### 앱 컨테이너가 먼저 실행 중이어야 함

모니터링 스택의 `perf-network`, `app-network`가 `external: true`로 선언되어 있어서,  
두 네트워크가 없으면 compose 실행이 실패한다.  
앱을 먼저 띄우면 `app-network`가 자동 생성된다.

```bash
# 앱이 아직 실행 중이 아니라면 먼저 실행
docker compose -f docker/docker-compose.yml up -d
```

### Docker 네트워크 생성

`perf-network`는 앱 compose가 생성하지 않으므로 수동으로 만든다.

```bash
docker network create perf-network
```

이미 존재하면 무시해도 된다 (`network with name perf-network already exists`는 에러 아님).

### 방화벽 포트 오픈

서버 보안 그룹 또는 방화벽에서 아래 포트를 인바운드 허용해야 한다.

| 포트 | 용도 |
|---|---|
| 3000 | Grafana |
| 9090 | Prometheus |
| 3100 | Loki |

## 실행

### 1. 프로젝트 루트에서 실행

```bash
make monitor-cloud-up
```

볼륨 마운트 경로에 `${PWD}`가 사용되므로 **반드시 프로젝트 루트**에서 실행해야 한다.

### 2. 정상 기동 확인

```bash
make monitor-cloud-logs
```

`grafana-cloud` 컨테이너에서 `HTTP Server Listen` 로그가 보이면 준비 완료.

Grafana 접속 후 datasource 연결 상태 확인:
- 주소: `http://<SERVER_IP>:3000`
- ID/PW: `admin` / `admin`
- 좌측 메뉴 → Connections → Data sources → Prometheus, Loki 모두 **Connected** 상태인지 확인

### 3. Prometheus 스크랩 확인

`http://<SERVER_IP>:9090/targets`에서 아래 job이 모두 UP인지 확인한다.

| Job | 대상 |
|---|---|
| `spring` | `app-dev:8080` |
| `prometheus` | `prometheus-cloud:9090` |
| `loki` | `loki-cloud:3100` |

## 부하 테스트 (k6)

### `cloud.env` 설정

k6가 요청을 보낼 서버 주소를 설정한다.

```bash
# perf/env/cloud.env
BASE_URL=http://<SERVER_IP>:8080
```

### k6 실행 (로컬 머신에서)

```bash
make perf ENV=cloud DOMAIN=test PERF_SCENARIO=smoke-test
```

k6 메트릭은 Prometheus remote write(`http://prometheus:9090/api/v1/write`)로 전송된다.  
cloud 환경에서 k6를 로컬 머신에서 실행하는 경우 Prometheus 주소를 서버 IP로 수정해야 한다.

```yaml
# docker/monitoring/compose/docker-compose.k6.yml
K6_PROMETHEUS_RW_SERVER_URL: http://<SERVER_IP>:9090/api/v1/write
```

### Grafana에서 결과 확인

Grafana → Explore → Prometheus 데이터소스에서 `k6_*` 메트릭 조회.

## 종료

```bash
make monitor-cloud-down
```

볼륨은 삭제되지 않는다. 데이터까지 초기화하려면:

```bash
docker compose -f docker/monitoring/compose/docker-compose.monitoring.cloud.yml down -v
```

## 로컬과의 차이점

| 항목 | 로컬 | 클라우드 |
|---|---|---|
| 실행 명령 | `make monitor-up` | `make monitor-cloud-up` |
| 앱 실행 포함 | O (test.yml 함께 실행) | X (앱 별도 배포 필요) |
| Grafana 포트 | 3001 | 3000 |
| 네트워크 | compose가 생성 | 외부에서 미리 생성 필요 |
| Loki 데이터 경로 | `/loki` | `/tmp/loki` |
| 로그 보존 기간 | 없음 | 7일 |

## 트러블슈팅

### `network perf-network not found`

```bash
docker network create perf-network
```

### `network app-network not found`

앱 컨테이너가 실행되어 있지 않은 것. 앱을 먼저 실행한다.

```bash
docker compose -f docker/docker-compose.yml up -d
```

### Prometheus가 `app-dev` 메트릭을 못 가져오는 경우

앱 컨테이너가 `app-network`에 속해 있는지 확인한다.

```bash
docker inspect app-dev --format '{{json .NetworkSettings.Networks}}'
```

`app-network` 항목이 있어야 한다.

### Loki에 로그가 안 쌓이는 경우

서버에서 Docker 소켓 접근 권한 확인:

```bash
ls -la /var/run/docker.sock
```

`promtail-cloud` 컨테이너가 해당 소켓을 읽을 수 있어야 한다.
