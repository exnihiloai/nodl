SHELL := /bin/bash
COMPOSE ?= docker compose
WEB ?= web
NOTIFY_ENV ?= private/notify.env

# Allow both: make notify MSG="Hello" and make notify Hello world
MSG_WORDS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
MSG ?= $(strip $(foreach w,$(MSG_WORDS),$(w) ))

.PHONY: help notify build up dev check check-fast db-check test test-fast coverage down logs shell lint seed skill skills skills-check skills-clean skill-new setup

help:
	@echo "Available targets:"
	@echo "  make build  # Build docker images"
	@echo "  make up     # Start local stack in background"
	@echo "  make dev    # Alias for 'make up'"
	@echo "  make check  # HANDOFF GATE: db-check + lint + full tests (run before handing off)"
	@echo "  make check-fast # Inner loop: db-check + lint + unit/integration tests (no system tests)"
	@echo "  make db-check # Apply migrations (runs strong_migrations) + assert db/schema.rb is in sync"
	@echo "  make test   # Run all Rails tests (unit/integration + system)"
	@echo "  make test-fast # Run unit/integration tests only (no system tests)"
	@echo "  make coverage # Run tests with SimpleCov; report to ./coverage/index.html"
	@echo "  make seed   # Seed database"
	@echo "  make lint   # Run rubocop + database_consistency (model<->DB constraint parity)"
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

# Single handoff gate. Order matters: db-check applies migrations so the dev DB
# (which database_consistency in `lint` inspects) reflects the current schema
# before lint runs.
check: db-check lint test

# Faster inner-loop variant: skips the browser/system tests.
check-fast: db-check lint test-fast

# Exercises strong_migrations (it only fires while migrations actually run) and
# asserts db/schema.rb is committed/in sync. Fails if an unsafe migration is
# detected (strong_migrations aborts) or if running migrations changes
# db/schema.rb (i.e. a migration was added but not applied/committed).
db-check:
	@set -e; \
	cp db/schema.rb /tmp/nodl-schema.pre; \
	$(COMPOSE) exec -T $(WEB) bin/rails db:migrate; \
	if ! cmp -s db/schema.rb /tmp/nodl-schema.pre; then \
		rm -f /tmp/nodl-schema.pre; \
		echo "ERROR: db:migrate changed db/schema.rb — a migration was not applied/committed."; \
		echo "       Commit the updated db/schema.rb (and confirm the migration is intended)."; \
		exit 1; \
	fi; \
	rm -f /tmp/nodl-schema.pre; \
	echo "db-check: migrations safe and db/schema.rb in sync."

test:
	$(COMPOSE) exec $(WEB) bin/rails db:test:prepare
	$(COMPOSE) exec $(WEB) bin/rails test
	$(COMPOSE) exec $(WEB) bin/rails test:system

test-fast:
	$(COMPOSE) exec $(WEB) bin/rails db:test:prepare
	$(COMPOSE) exec $(WEB) bin/rails test

coverage:
	$(COMPOSE) exec $(WEB) bin/rails db:test:prepare
	$(COMPOSE) exec -e COVERAGE=1 $(WEB) bin/rails test
	@echo "Coverage report written to ./coverage/index.html"

seed:
	$(COMPOSE) exec $(WEB) bin/rails db:seed

lint:
	$(COMPOSE) exec $(WEB) bin/rubocop
	$(COMPOSE) exec $(WEB) bundle exec database_consistency -c .database_consistency.todo.yml

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
