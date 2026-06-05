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

# --- GCP project bootstrap -------------------------------------------------

bootstrap_gcp:  ## One-shot: create GCP project + link billing + state bucket + WIF SA. Needs BILLING_ACCOUNT env.
	./scripts/bootstrap-gcp.sh

# --- GitHub secrets / variables --------------------------------------------

sync_gh:  ## Upload gh-vars + gh-secrets dotenv files to all 3 deepCab repos.
	./scripts/sync-gh-secrets.sh

# --- Showcase up/down toggle -----------------------------------------------
# `showcase_up`  : flip Cloud SQL ALWAYS + Uptime Kuma min=1 (~$15/mo).
# `showcase_down`: flip Cloud SQL NEVER  + Uptime Kuma min=0 (~$0/mo idle).
# Apply targets the dev env. Pass ENV=staging / prod to scope elsewhere.

showcase_up:  ## Bring the showcase stack live (~$15/mo until showcase_down).
	@cd $(TF_DIR) && terraform apply -input=false -auto-approve -var='showcase_mode=true'
	@echo
	@echo "Live URLs:"
	@cd $(TF_DIR) && terraform output -raw api_service_url   2>/dev/null && echo "  ← api"
	@cd $(TF_DIR) && terraform output -raw website_service_url 2>/dev/null && echo "  ← website"
	@cd $(TF_DIR) && terraform output -raw mlflow_service_url 2>/dev/null && echo "  ← mlflow"
	@cd $(TF_DIR) && terraform output -raw status_page_url    2>/dev/null && echo "  ← status page (Uptime Kuma)"

showcase_down:  ## Stop Cloud SQL + scale Uptime Kuma to zero. Idle cost ~$0.
	@cd $(TF_DIR) && terraform apply -input=false -auto-approve -var='showcase_mode=false'
	@echo
	@echo "Stack down. Cloud SQL stopped, Uptime Kuma min=0."
	@echo "Cloud Run services exist but scale to zero — no compute billed."
	@echo "Bring back with: make showcase_up"

# --- MLflow image lifecycle ------------------------------------------------

mlflow_mirror:  ## Mirror ghcr.io/mlflow/mlflow → GAR via Cloud Build. Re-run after bumping the version in cloud-manifests/mlflow/mirror.yaml.
	gcloud builds submit --config=cloud-manifests/mlflow/mirror.yaml --no-source --project=$$(cd $(TF_DIR) && terraform output -raw project_id)

# --- Housekeeping ----------------------------------------------------------

clean:  ## Wipe local .terraform caches.
	find terraform -type d -name '.terraform' -prune -exec rm -rf {} +
	find terraform -name '.terraform.lock.hcl' -delete
	@echo "Cleaned local terraform caches."
