# mist-ce developer Makefile
# Run `make dev` after a fresh clone — that's it.
# Works on Linux (x86_64) and macOS (Apple Silicon arm64).

.DEFAULT_GOAL := help
SHELL := /bin/bash
DC := docker compose

ADMIN_EMAIL ?= admin@example.com
ADMIN_PASSWORD ?= admin
PORTAL_URI ?= http://localhost

# ------------------------------------------------------------------------------
# Composite targets
# ------------------------------------------------------------------------------

.PHONY: dev
dev: setup build up npm adduser ## Full fresh-clone bootstrap → running login page (idempotent, ~15-25 min first run)
	@echo ""
	@echo "=========================================================="
	@echo " mist-ce is up at $(PORTAL_URI)"
	@echo " Login: $(ADMIN_EMAIL) / $(ADMIN_PASSWORD)"
	@echo "=========================================================="

.PHONY: setup
setup: .env submodules settings/settings.py keys ## Create .env, init submodules, scaffold settings/ + keys/

# ------------------------------------------------------------------------------
# Scaffolding (idempotent file targets)
# ------------------------------------------------------------------------------

.env:
	@echo "→ creating .env from template"
	cp .env.template .env

.PHONY: submodules
submodules:
	@if ! git submodule status | grep -q '^ '; then \
		echo "→ initializing git submodules (api/lc)"; \
		git submodule update --init --recursive; \
	fi

settings/settings.py:
	@echo "→ scaffolding settings/settings.py"
	mkdir -p settings
	cp api/settings/settings.py settings/settings.py
	sed -i.bak -e 's|^PORTAL_URI = .*|PORTAL_URI = "$(PORTAL_URI)"|' \
	           -e 's|^JS_BUILD = .*|JS_BUILD = False|' \
	           settings/settings.py && rm -f settings/settings.py.bak

keys:
	mkdir -p keys

# ------------------------------------------------------------------------------
# Docker lifecycle
# ------------------------------------------------------------------------------

.PHONY: build
build: setup ## Build all images locally (required — published images are gone)
	@echo "→ building images (arch: $$(uname -m))"
	$(DC) build

.PHONY: up
up: setup ## Start the stack detached and wait for init chain
	$(DC) up -d
	@echo "→ waiting for init chain (vault-init → init-secrets → apply-migrations)..."
	@for svc in vault-init init-secrets apply-migrations; do \
		printf "   %-20s " $$svc; \
		cid=$$($(DC) ps -q $$svc); \
		if [ -z "$$cid" ]; then echo "? not found"; continue; fi; \
		code=$$(docker wait $$cid); \
		if [ "$$code" = "0" ]; then echo "ok"; \
		else echo "FAILED (exit $$code) — run: $(DC) logs $$svc"; exit 1; fi; \
	done
	@echo "→ waiting for api uwsgi to come up..."
	@for i in $$(seq 1 90); do \
		$(DC) exec -T api pgrep -f uwsgi >/dev/null 2>&1 && { echo "   api ready"; break; }; \
		sleep 2; \
	done

.PHONY: npm
npm: ## Install frontend deps into bind-mounted ui/ + portal/ (fixes blank page)
	@echo "→ npm install (ui)"
	$(DC) exec -T ui npm install --no-audit --no-fund
	@echo "→ npm install (portal)"
	$(DC) exec -T portal npm install --no-audit --no-fund
	$(DC) restart ui portal

.PHONY: adduser
adduser: ## Create/update admin account (ADMIN_EMAIL=... ADMIN_PASSWORD=...)
	$(DC) exec -T api ./bin/adduser --admin -p "$(ADMIN_PASSWORD)" "$(ADMIN_EMAIL)"

.PHONY: down
down: ## Stop the stack (keeps volumes)
	$(DC) down

.PHONY: clean
clean: ## Stop + delete Docker volumes (wipes DB/vault data, keeps scaffolding)
	$(DC) down -v

.PHONY: purge
purge: ## Full reset to fresh-clone state — removes volumes, .env, settings/, keys/, node_modules, built images
	@echo "→ removing locally built images"
	-@if [ -f .env ]; then \
		imgs=$$($(DC) config --images 2>/dev/null); \
		[ -n "$$imgs" ] && docker rmi -f $$imgs 2>/dev/null || true; \
	fi
	@echo "→ stopping and deleting volumes"
	-$(DC) down -v 2>/dev/null || true
	@echo "→ removing scaffolding"
	rm -rf .env settings keys
	rm -rf ui/node_modules portal/node_modules
	@echo "→ done — repo is back to fresh-clone state"
	@echo "   (submodules kept; 'git submodule deinit --all -f' to drop those too)"

.PHONY: restart
restart: ## Hot-reload api + dramatiq (delegates to restart.sh)
	./restart.sh $(filter-out $@,$(MAKECMDGOALS))

.PHONY: logs
logs: ## Tail all logs (make logs svc=api to filter)
	$(DC) logs -f $(svc)

.PHONY: ps
ps: ## Show container status
	$(DC) ps -a

# ------------------------------------------------------------------------------
# Shells
# ------------------------------------------------------------------------------

.PHONY: sh sh-api sh-ui sh-portal sh-mongo
sh: sh-api ## Alias for sh-api
sh-api: ## Shell into api container
	$(DC) exec api bash
sh-ui: ## Shell into ui container
	$(DC) exec ui sh
sh-portal: ## Shell into portal container
	$(DC) exec portal sh
sh-mongo: ## Mongo shell
	$(DC) exec mongodb mongosh mist2

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

.PHONY: help
help:
	@echo "mist-ce — common targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Fresh clone?  →  make dev"
	@echo "Custom admin? →  make dev ADMIN_EMAIL=me@foo.com ADMIN_PASSWORD=secret"
	@echo "Remote VM?    →  make dev PORTAL_URI=http://<vm-ip>"

# swallow extra args to `make restart foo`
%:
	@:
