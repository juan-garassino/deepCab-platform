# deepCab platform — Makefile
#
# Env-scoped wrappers around Terraform. Default env is `dev`.
#
#   make ENV=staging plan
#   make ENV=prod apply
#   make fmt
#   make validate

ENV ?= dev
TF_DIR := terraform/envs/$(ENV)

.PHONY: help plan apply destroy fmt fmt_check validate init init_no_backend output show \
        lint workflows_lint clean print_env

help:  ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make ENV=<env> <target>\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

print_env:
	@echo "ENV=$(ENV)  TF_DIR=$(TF_DIR)"

# --- Terraform lifecycle ----------------------------------------------------

init:  ## terraform init (with GCS backend).
	cd $(TF_DIR) && terraform init -input=false

init_no_backend:  ## terraform init without backend — for local validate/fmt only.
	cd $(TF_DIR) && terraform init -backend=false -input=false

plan: init  ## terraform plan for $ENV.
	cd $(TF_DIR) && terraform plan -input=false

apply: init  ## terraform apply for $ENV.
	cd $(TF_DIR) && terraform apply -input=false

destroy: init  ## terraform destroy for $ENV — be careful.
	cd $(TF_DIR) && terraform destroy -input=false

output:  ## Print terraform outputs for $ENV.
	cd $(TF_DIR) && terraform output

show:  ## Show current state for $ENV.
	cd $(TF_DIR) && terraform show

# --- Formatting + validation -----------------------------------------------

fmt:  ## terraform fmt -recursive on the whole tree.
	terraform fmt -recursive terraform/

fmt_check:  ## CI: fail if any TF file isn't formatted.
	terraform fmt -check -recursive terraform/

validate:  ## Validate every env (backend disabled, no real GCS access).
	@set -e; for d in terraform/envs/*/; do \
		echo "==> $$d"; \
		(cd $$d && terraform init -backend=false -input=false -no-color >/dev/null && terraform validate -no-color); \
	done
	@echo "All envs validate OK."

workflows_lint:  ## Sanity-check YAML in .github/workflows/.
	@for f in .github/workflows/*.yml; do \
		python3 -c "import yaml; yaml.safe_load(open('$$f'))" && echo "$$f OK"; \
	done

lint: fmt_check validate workflows_lint  ## All checks (fmt + validate + workflows).

# --- Python CLI entrypoint (Wave 3) ---------------------------------------
# All targets below now wrap `deepcab-platform` (Typer CLI, Pydantic-typed,
# DryRun providers). The bash scripts in scripts/ became thin shims for
# backwards-compat. Direct CLI access: `uv run deepcab-platform <subcmd>`.

cli:  ## Open the deepcab-platform help.
	uv run deepcab-platform --help

status:  ## Print resolved DEEPCAB_ENV settings.
	uv run deepcab-platform status

bootstrap_gcp:  ## One-shot: create GCP project + link billing + state bucket + WIF SA.
	@if [ -z "$$BILLING_ACCOUNT" ] || [ -z "$$PROJECT_ID" ]; then \
		echo "Required: BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX PROJECT_ID=deepcab-<env> make bootstrap_gcp ENV=<env>"; \
		exit 1; \
	fi
	uv run deepcab-platform bootstrap --env $(ENV) --billing-account $$BILLING_ACCOUNT --project-id $$PROJECT_ID

sync_gh:  ## Upload gh-vars + gh-secrets dotenv files to all 3 deepCab repos.
	uv run deepcab-platform sync-gh

mlflow_mirror:  ## Mirror ghcr.io/mlflow/mlflow → GAR via Cloud Build.
	uv run deepcab-platform mlflow mirror --project-id $$(cd $(TF_DIR) && terraform output -raw project_id)

showcase_up:  ## Bring the showcase stack live (Cloud SQL ALWAYS, Kuma min=1, ~$15/mo).
	uv run deepcab-platform showcase up --env $(ENV)

showcase_down:  ## Stop Cloud SQL + Kuma min=0 (~$1/mo idle).
	uv run deepcab-platform showcase down --env $(ENV)

kuma_seed:  ## Pre-configure Uptime Kuma monitors via REST API.
	uv run deepcab-platform kuma seed

# --- Housekeeping ----------------------------------------------------------

clean:  ## Wipe local .terraform caches.
	find terraform -type d -name '.terraform' -prune -exec rm -rf {} +
	find terraform -name '.terraform.lock.hcl' -delete
	@echo "Cleaned local terraform caches."
