MONITORING := monitoring/compose/docker-compose.monitoring.yml

# ─── 모니터링 스택 (로컬) ─────────────────────────────────────
.PHONY: monitor-up monitor-down monitor-logs

monitor-up:
	docker compose $(MONITORING) --env-file .env up -d --remove-orphans

monitor-down:
	docker compose $(MONITORING) --env-file .env down

monitor-logs:
	docker compose $(MONITORING) --env-file .env logs -f

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
	@echo ""
