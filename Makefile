MONITORING := docker/monitoring/compose/docker-compose.monitoring.yml

# ─── 모니터링 스택 (클라우드) ────────────────────────────────
.PHONY: monitor-cloud-up monitor-cloud-down monitor-cloud-logs

monitor-up:
	docker compose -f $(MONITORING) up -d --remove-orphans

monitor-down:
	docker compose -f $(MONITORING) down

monitor-logs:
	docker compose -f $(MONITORING) logs -f

# ─── 편의 명령 ───────────────────────────────────────────────
.PHONY: help

help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  monitor-cloud-up    클라우드 모니터링 스택 시작"
	@echo "  monitor-cloud-down  클라우드 모니터링 스택 종료"
	@echo "  monitor-cloud-logs  클라우드 모니터링 스택 로그 확인"
	@echo ""
	@echo ""
