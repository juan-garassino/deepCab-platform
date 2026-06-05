# `terraform/` — deepCab IaC

Layered Terraform tree that provisions the entire GCP shape of deepCab.
The 001 (API) repo never `gcloud`'s anything about service shape; it only
builds + pushes images and does `gcloud run services update --image=...`.
Every other knob lives here.

## Layout

```
terraform/
├── modules/      # reusable building blocks (provider versions pinned per module)
└── envs/         # per-env composition (dev, staging, prod)
```

## Modules

| Module | Resource(s) | Status |
|---|---|---|
| `gar` | Artifact Registry repo (with cleanup policies) | always-on |
| `storage` | 3 GCS buckets (mlflow, models, tfstate) | always-on |
| `cloud_sql` | Cloud SQL Postgres + databases + users | always-on |
| `secret_manager` | Secret containers + accessor IAM | always-on |
| `wif` | Workload Identity Pool + Provider + 4 SAs + bindings | always-on |
| `cloud_run` | `deepcab-api` service (v2) | always-on |
| `cloud_run_website` | `deepcab-website` service (v2) — nginx-served Vite SPA | always-on |
| `cloud_run_job` | `deepcab-retrain` job (v2) | always-on |
| `scheduler` | Cloud Scheduler firing the job | always-on |
| `vpc` | VPC + Cloud NAT + private services connection | gated (`enabled = false` in dev) |
| `gke` | GKE Standard cluster + node pool | gated (`enabled = false` default) |
| `dns` | Managed zone records | gated (empty `zone_name` disables) |
| `iam` | Cross-cutting bindings + billing budget | always-on (mostly no-ops without inputs) |

## Envs

| Env | API (Cloud Run) | Website (Cloud Run) | Cloud SQL | VPC | DNS | GKE | Budget |
|---|---|---|---|---|---|---|---|
| `dev` | cpu=1 mem=512Mi min=0 max=2 | cpu=1 mem=256Mi min=0 max=2 | db-f1-micro, public IP | disabled | disabled | disabled | none |
| `staging` | cpu=1 mem=1Gi min=0 max=4 | cpu=1 mem=256Mi min=1 max=4 | db-g1-small, private IP | enabled | optional | disabled | none |
| `prod` | cpu=2 mem=2Gi min=1 max=10 | cpu=1 mem=512Mi min=2 max=10 | db-custom-2-4096, HA + PITR | enabled | enabled | optional | $200/mo alert |

## Quickstart

```bash
# From repo root:
make ENV=dev plan
make ENV=dev apply

# Each env has its own state bucket — see RUNBOOK.md for the one-time
# bootstrap (chicken-and-egg: bucket must exist before `terraform init`).
```

## Editing modules

1. Make the change in `modules/<m>/`.
2. `make fmt` (terraform fmt -recursive).
3. `make validate` to verify each env still validates.
4. Open a PR — `.github/workflows/platform-plan.yml` posts the plan per env.
5. Merge to main — `.github/workflows/platform-apply.yml` applies in order
   dev → staging → prod (with manual approval gates).

## Editing envs

`envs/<env>/main.tf` composes the modules. `envs/<env>/terraform.tfvars` provides
the per-env values (project ID, project number, image tags, DNS zone, etc.).
Never commit real secrets here — those live in Secret Manager.
