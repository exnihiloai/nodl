SHELL := /bin/bash
COMPOSE ?= docker compose
WEB ?= web
NOTIFY_ENV ?= private/notify.env

# Allow both: make notify MSG="Hello" and make notify Hello world
MSG_WORDS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
MSG ?= $(strip $(foreach w,$(MSG_WORDS),$(w) ))

.PHONY: help notify build up dev test down logs shell lint seed skill skills skills-check skills-clean skill-new setup

help:
	@echo "Available targets:"
	@echo "  make build  # Build docker images"
	@echo "  make up     # Start local stack in background"
	@echo "  make dev    # Alias for 'make up'"
	@echo "  make test   # Run all Rails tests (unit/integration + system)"
	@echo "  make seed   # Seed database"
	@echo "  make lint   # Run rubocop"
	@echo "  make skill  # Alias for 'make skills'"
	@echo "  make skills # Generate Claude/Codex skill outputs from canonical /skills"
	@echo "  make skills-check # Verify generated skill outputs are up to date"
	@echo "  make skills-clean # Remove generated skill outputs"
	@echo "  make skill-new ID=<id> NAME=\"<Skill Name>\" # Create canonical skill scaffold"
	@echo "  make setup  # Configure git hooks (run once after cloning)"
	@echo "  make notify MSG=\"Hello\"  # Send a Telegram message (uses local private/notify.env)"
	@echo "  make logs   # Follow logs"
	@echo "  make shell  # Open bash in web container"
	@echo "  make down   # Stop and remove stack"

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

dev: up

test:
	$(COMPOSE) exec $(WEB) bin/rails db:test:prepare
	$(COMPOSE) exec $(WEB) bin/rails test
	$(COMPOSE) exec $(WEB) bin/rails test:system

seed:
	$(COMPOSE) exec $(WEB) bin/rails db:seed

lint:
	$(COMPOSE) exec $(WEB) bin/rubocop

skill: skills

skills:
	./scripts/skills.sh generate

skills-check:
	./scripts/skills.sh check

skills-clean:
	./scripts/skills.sh clean

skill-new:
	@if [ -z "$(ID)" ] || [ -z "$(NAME)" ]; then \
		echo 'Usage: make skill-new ID=<skill-id> NAME="<Skill Name>"'; \
		exit 1; \
	fi
	./scripts/skill_new.sh "$(ID)" "$(NAME)"

setup:
	git config core.hooksPath .githooks
	@echo "Git hooks configured. post-merge will auto-run 'make skills' when skills/ changes."

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

shell:
	$(COMPOSE) exec $(WEB) bash

notify:
	@MSG_TEXT='$(MSG)'; \
	if [ -f "$(NOTIFY_ENV)" ]; then \
		set -a; . "$(NOTIFY_ENV)"; set +a; \
	fi; \
	: $${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN or create $(NOTIFY_ENV)}; \
	: $${TELEGRAM_CHAT_ID:?set TELEGRAM_CHAT_ID or create $(NOTIFY_ENV)}; \
	PAYLOAD=$$(python3 -c 'import json, sys; print(json.dumps({"chat_id": sys.argv[1], "text": sys.argv[2], "disable_web_page_preview": True}))' "$$TELEGRAM_CHAT_ID" "$$MSG_TEXT"); \
	curl -sS -X POST "https://api.telegram.org/bot$${TELEGRAM_BOT_TOKEN}/sendMessage" \
		-H "Content-Type: application/json" \
		--data "$$PAYLOAD" \
		>/dev/null && echo Sent.

# Dummy rule so extra words in `make notify hello world` are not treated as errors.
%:
	@:
