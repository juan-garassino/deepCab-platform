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

# --- Housekeeping ----------------------------------------------------------

clean:  ## Wipe local .terraform caches.
	find terraform -type d -name '.terraform' -prune -exec rm -rf {} +
	find terraform -name '.terraform.lock.hcl' -delete
	@echo "Cleaned local terraform caches."
