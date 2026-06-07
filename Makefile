SHELL := /bin/bash
COMPOSE ?= docker compose
WEB ?= web
NOTIFY_ENV ?= private/notify.env

# Deployment: build the prod image for the server arch, push to a registry,
# then trigger the Dokploy redeploy webhook. Operator-specific values
# (DEPLOY_IMAGE, DOKPLOY_DEPLOYMENT_HOOK) live in $(DEPLOY_ENV), not in this
# public file, so forks/other operators configure their own without editing it.
DEPLOY_PLATFORM ?= linux/amd64
BUILDX_BUILDER ?= nodlbuilder
DEPLOY_ENV ?= private/.env
# Image to scan with `make image-audit`. Empty by default; falls back to
# $(DEPLOY_IMAGE):latest from $(DEPLOY_ENV), or pass IMAGE=repo:tag explicitly.
IMAGE ?=
VERSION ?= $(shell grep -m1 -oE '\[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '[]')

# Allow both: make notify MSG="Hello" and make notify Hello world
MSG_WORDS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
MSG ?= $(strip $(foreach w,$(MSG_WORDS),$(w) ))

.PHONY: help notify build up dev check check-fast db-check test test-fast coverage down logs shell lint audit image-audit seed skill skills skills-check skills-clean skill-new setup deploy

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
	@echo "  make audit  # Scan gems for known CVEs (bundler-audit vs rubysec ruby-advisory-db)"
	@echo "  make image-audit [IMAGE=repo:tag] [FORMAT=html|txt] # Trivy scan a built image (OS + gems + secrets)"
	@echo "  make skill  # Alias for 'make skills'"
	@echo "  make skills # Generate Claude/Codex skill outputs from canonical /skills"
	@echo "  make skills-check # Verify generated skill outputs are up to date"
	@echo "  make skills-clean # Remove generated skill outputs"
	@echo "  make skill-new ID=<id> NAME=\"<Skill Name>\" # Create canonical skill scaffold"
	@echo "  make setup  # Configure git hooks (run once after cloning)"
	@echo "  make deploy # Build+push amd64 image (DEPLOY_IMAGE) to your registry and trigger the Dokploy redeploy webhook"
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

# Dependency CVE scan. Deliberately NOT part of `make check`: it needs network
# (to refresh the advisory DB) and a new advisory can fail it without any code
# change, so it stays a standalone target to run periodically and before deploy.
# Single source: the local rubysec ruby-advisory-db (no dependency data leaves
# this machine). Add an `ignore:` entry in config/bundler-audit.yml for any
# advisory that does not apply.
audit:
	$(COMPOSE) exec $(WEB) bundle exec bundler-audit check --update --config config/bundler-audit.yml

# Container image CVE scan via Trivy: covers the OS layer (Debian packages like
# openssl) plus bundled gems and leaked secrets — things `make audit` (which
# only reads Gemfile.lock) cannot see. Kept separate from `make audit` because
# it scans a *built image*, which is only meaningful right after a build.
#
# Informational only — it reports HIGH/CRITICAL with an available fix and does
# not fail. Writes a timestamped report to $(IMAGE_AUDIT_DIR)/ instead of
# flooding the terminal; only a one-line summary + the file path are printed.
# Scans $(IMAGE); defaults to your deploy image (from $(DEPLOY_ENV)) or pass one
# explicitly, e.g. `make image-audit IMAGE=nodl-prod-verify:latest`. Trivy runs
# as a container and downloads its vuln DB into a local cache volume; nothing
# about the image leaves this machine.
IMAGE_AUDIT_DIR ?= tmp/security
# Report format: html (styled, opens in a browser and prints to PDF via Cmd-P;
# default) or txt (plain table).
FORMAT ?= html
image-audit:
	@IMG="$(IMAGE)"; \
	if [ -z "$$IMG" ] && [ -f "$(DEPLOY_ENV)" ]; then \
		set -a; . "$(DEPLOY_ENV)"; set +a; \
		[ -n "$$DEPLOY_IMAGE" ] && IMG="$$DEPLOY_IMAGE:latest"; \
	fi; \
	if [ -z "$$IMG" ]; then \
		echo "Usage: make image-audit IMAGE=<repo:tag>  (or set DEPLOY_IMAGE in $(DEPLOY_ENV))"; \
		exit 1; \
	fi; \
	case "$(FORMAT)" in \
		txt)  ext=txt;  targs="--format table" ;; \
		html) ext=html; targs="--format template --template @/contrib/html.tpl" ;; \
		*)    echo "Unknown FORMAT=$(FORMAT) (use txt or html)"; exit 1 ;; \
	esac; \
	mkdir -p "$(IMAGE_AUDIT_DIR)"; \
	base="image-audit-$$(date +%Y%m%d-%H%M%S)"; \
	echo "==> Trivy scanning $$IMG (HIGH/CRITICAL, fixable) ..."; \
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v trivy-cache:/root/.cache/ \
		-v "$(CURDIR)/$(IMAGE_AUDIT_DIR)":/out \
		aquasec/trivy:latest image \
		--quiet --severity HIGH,CRITICAL --ignore-unfixed --skip-version-check \
		$$targs --output "/out/$$base.$$ext" \
		"$$IMG"; \
	report="$(IMAGE_AUDIT_DIR)/$$base.$$ext"; \
	count=$$(grep -oE 'CVE-[0-9]{4}-[0-9]+' "$$report" 2>/dev/null | sort -u | wc -l | tr -d ' '); \
	echo "==> $$count distinct HIGH/CRITICAL CVE(s) with a fix. Report: $$report"

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

# Build the production image for the server's architecture (the dev Mac is
# arm64, the VPS is amd64), push both :$(VERSION) and :latest to the registry,
# then trigger Dokploy to pull & redeploy via its webhook. Operator-specific
# values come from $(DEPLOY_ENV) (git-ignored): DEPLOY_IMAGE (e.g.
# youruser/nodl) and DOKPLOY_DEPLOYMENT_HOOK. Reminder: the image MUST be built
# locally because private/ (legal pages, telemetry initializer) is git-ignored
# and only exists on disk here.
deploy:
	@set -e; \
	if [ -z "$(VERSION)" ]; then \
		echo "ERROR: could not derive VERSION from CHANGELOG.md (expected '## [X.Y.Z]')."; exit 1; \
	fi; \
	if [ ! -f "$(DEPLOY_ENV)" ]; then \
		echo "ERROR: $(DEPLOY_ENV) not found (needs DEPLOY_IMAGE and DOKPLOY_DEPLOYMENT_HOOK)."; exit 1; \
	fi; \
	set -a; . "$(DEPLOY_ENV)"; set +a; \
	: $${DEPLOY_IMAGE:?set DEPLOY_IMAGE (e.g. youruser/nodl) in $(DEPLOY_ENV)}; \
	: $${DOKPLOY_DEPLOYMENT_HOOK:?set DOKPLOY_DEPLOYMENT_HOOK in $(DEPLOY_ENV)}; \
	echo "==> Building $$DEPLOY_IMAGE:$(VERSION) (+ :latest) for $(DEPLOY_PLATFORM)"; \
	docker buildx inspect "$(BUILDX_BUILDER)" >/dev/null 2>&1 || \
		docker buildx create --name "$(BUILDX_BUILDER)" --driver docker-container --bootstrap >/dev/null; \
	docker buildx build --builder "$(BUILDX_BUILDER)" --platform "$(DEPLOY_PLATFORM)" \
		-t "$$DEPLOY_IMAGE:$(VERSION)" -t "$$DEPLOY_IMAGE:latest" --push .; \
	echo "==> Pushed $$DEPLOY_IMAGE:$(VERSION) and $$DEPLOY_IMAGE:latest"; \
	echo "==> Triggering Dokploy redeploy webhook"; \
	curl -fsSL -X POST "$$DOKPLOY_DEPLOYMENT_HOOK" >/dev/null; \
	echo "==> Dokploy redeploy triggered. Watch the container logs in the Dokploy dashboard."; \
	echo "    Tip: if you changed static files in public/ (icons, logos), purge the Cloudflare cache."

# Dummy rule so extra words in `make notify hello world` are not treated as errors.
%:
	@:
