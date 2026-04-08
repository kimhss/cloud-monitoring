MONITORING_LOCAL := docker/monitoring/compose/docker-compose.monitoring.local.yml
MONITORING_CLOUD := docker/monitoring/compose/docker-compose.monitoring.cloud.yml

# ─── 모니터링 스택 (로컬) ─────────────────────────────────────
.PHONY: monitor-up monitor-down monitor-logs

monitor-up:
	docker compose \
	  -f docker/docker-compose.test.yml \
	  -f $(MONITORING_LOCAL) --env-file .env up -d --remove-orphans

monitor-down:
	docker compose \
	  -f docker/docker-compose.test.yml \
	  -f $(MONITORING_LOCAL) --env-file .env down

monitor-logs:
	docker compose \
	  -f docker/docker-compose.test.yml \
	  -f $(MONITORING_LOCAL) --env-file .env logs -f

# ─── 모니터링 스택 (클라우드) ─────────────────────────────────
.PHONY: monitor-cloud-up monitor-cloud-down monitor-cloud-logs

monitor-cloud-up:
	docker compose -f $(MONITORING_CLOUD) up -d

monitor-cloud-down:
	docker compose -f $(MONITORING_CLOUD) down

monitor-cloud-logs:
	docker compose -f $(MONITORING_CLOUD) logs -f

# ─── k6 실행 ────────────────────────────────────────────────
.PHONY: k6

k6:
	docker compose \
    	-f docker/monitoring/compose/docker-compose.k6.yml \
    	run --rm k6

# ─── 성능 테스트 ─────────────────────────────────────────────
ENV ?= local
ENV_FILE := perf/env/$(ENV).env

PERF_SCENARIO ?= smoke-test
DOMAIN ?= test
PERF_SCRIPT   ?= /scripts/$(DOMAIN)/$(PERF_SCENARIO).js

PERF_RESULTS_ROOT := perf/results
PERF_TS := $(shell date +"%Y%m%d-%H%M%S")
PERF_OUT_DIR := $(PERF_RESULTS_ROOT)/$(ENV)/$(DOMAIN)/$(PERF_SCENARIO)
PERF_OUT_JSON := /results/$(ENV)/$(DOMAIN)/$(PERF_SCENARIO)/$(PERF_SCENARIO)-$(PERF_TS).json

perf-check-env:
	@test -f "$(ENV_FILE)" || (echo "❌ env file not found: $(ENV_FILE)"; exit 1)
	@mkdir -p "$(PERF_OUT_DIR)"

perf: perf-check-env
	@echo "▶ Running k6 scenario=$(PERF_SCENARIO) ENV=$(ENV)"
	MSYS_NO_PATHCONV=1 docker compose \
	  -f docker/monitoring/compose/docker-compose.k6.yml \
	  --profile k6 run --rm \
	  $$(grep -vE '^\s*#|^\s*$$' "$(ENV_FILE)" | sed 's/\r$$//' | awk -F= '{printf "-e %s=%s ", $$1, $$2}') \
	  k6 run \
	  --summary-export="$(PERF_OUT_JSON)" \
	  "$(PERF_SCRIPT)"
	@echo "✅ Saved: perf/results/$(ENV)/$(PERF_SCENARIO)-$(PERF_TS).json"

# ─── 편의 명령 ───────────────────────────────────────────────
.PHONY: help

help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  monitor-up          로컬 모니터링 스택 시작 (Prometheus, Grafana, Loki, Promtail)"
	@echo "  monitor-down        로컬 모니터링 스택 종료"
	@echo "  monitor-logs        로컬 모니터링 스택 로그 확인"
	@echo ""
	@echo "  monitor-cloud-up    클라우드 모니터링 스택 시작"
	@echo "  monitor-cloud-down  클라우드 모니터링 스택 종료"
	@echo "  monitor-cloud-logs  클라우드 모니터링 스택 로그 확인"
	@echo ""
	@echo "  perf                k6 성능 테스트 실행"
	@echo "    ENV=local|cloud   대상 환경 (기본: local)"
	@echo "    DOMAIN=<도메인>   테스트 도메인"
	@echo "    PERF_SCENARIO=<시나리오>  스크립트 이름 (기본: test)"
	@echo ""
	@echo "  예시:"
	@echo "    make perf ENV=local DOMAIN=auth PERF_SCENARIO=smoke"
	@echo "    make perf ENV=cloud DOMAIN=auth PERF_SCENARIO=load"
	@echo ""
