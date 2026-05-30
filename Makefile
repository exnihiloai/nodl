SHELL := /bin/bash
COMPOSE ?= docker compose
WEB ?= web

.PHONY: help build up dev test down logs shell lint seed skill skills skills-check skills-clean skill-new setup

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
