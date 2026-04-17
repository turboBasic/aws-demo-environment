.DEFAULT_GOAL := help

TESTS_DIR := tests

# Run commands through the mise-managed uv-managed virtualenv.
UV  := mise exec -- uv
RUN := $(UV) run

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# ── Linting ───────────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## Run all linters via pre-commit (ruff, yamllint, shellcheck, actionlint, terraform, …)
	$(RUN) pre-commit run --all-files

# ── Install ───────────────────────────────────────────────────────────────────

.PHONY: install
install: ## Install Python dev dependencies via uv
	$(UV) sync --frozen

# ── Update UV lock file ───────────────────────────────────────────────────────

.PHONY: lock
lock: ## Regenerate uv.lock from pyproject.toml
	$(UV) lock
