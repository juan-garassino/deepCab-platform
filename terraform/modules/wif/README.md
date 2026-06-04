# Module: `wif`

**Replaces** `001-deepCab-api/infra/gcp/workload-identity/bootstrap.sh`. Provisions
the entire OIDC + service-account setup that lets GitHub Actions deploy to GCP
**without long-lived JSON keys**.

## What it builds

- 1 Workload Identity Pool (`github-pool`)
- 1 OIDC Provider (`github-provider`), restricted via `attribute_condition` to the configured GH owner
- 4 service accounts:
  - `deepcab-deployer`   — impersonated by 001's image-build/deploy workflows
  - `deepcab-runtime`    — attached to Cloud Run / Jobs / GKE at runtime
  - `deepcab-scheduler`  — invokes the retrain Job from Cloud Scheduler
  - `deepcab-terraform`  — impersonated by THIS platform repo's plan/apply workflows
- Project-level IAM bindings per SA (configurable via `*_project_roles` lists)
- `workloadIdentityUser` bindings:
  - `gh_owner/gh_repo`            -> `deployer`
  - `gh_owner/platform_gh_repo`   -> `terraform`
- `serviceAccountUser` bindings:
  - `deployer`   -> `runtime`
  - `terraform`  -> `runtime`
  - `terraform`  -> `scheduler`
- All required APIs enabled (IAM, GAR, Cloud Run, GKE, Secret Manager, Scheduler, SQL, Compute)

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | GCP project ID. |
| `project_number` | `string` | — | Numeric project number (used in `principalSet`). |
| `gh_owner` | `string` | — | GH org/user that owns both repos. |
| `gh_repo` | `string` | — | GH repo that builds images (e.g. `deepCab`). |
| `platform_gh_repo` | `string` | `"deepCab-platform"` | GH repo of this platform repo. |
| `pool_id` | `string` | `"github-pool"` | |
| `provider_id` | `string` | `"github-provider"` | |
| `deployer_sa_id` / `runtime_sa_id` / `scheduler_sa_id` / `terraform_sa_id` | `string` | `"deepcab-…"` | Account IDs. |
| `deployer_project_roles` / `runtime_project_roles` / `terraform_project_roles` | `list(string)` | see `variables.tf` | Project-level roles. Tune per env. |
| `labels` | `map(string)` | `{}` | |

## Outputs

| Name | Description |
|---|---|
| `pool_name` | Full resource name of the pool. |
| `provider_name` | Full resource name of the provider — paste into GH `workload_identity_provider:`. |
| `deployer_sa_email` | Deployer SA. |
| `runtime_sa_email` | Runtime SA (used by `cloud_run` / `cloud_run_job` modules). |
| `scheduler_sa_email` | Scheduler SA (used by `scheduler` module). |
| `terraform_sa_email` | Terraform CI SA. |

## GitHub Actions snippet

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}    # = output.provider_name
    service_account: ${{ vars.GCP_DEPLOYER_SA }}                # = output.deployer_sa_email
```

## Why the project-roles defaults are broad

The `deployer` and `terraform` SAs need permission to mutate Cloud Run, GKE,
IAM, Artifact Registry, Cloud SQL, etc. The defaults are a starting point —
**tighten them per environment** by overriding `*_project_roles` from the env's
`main.tf`. Production should drop `roles/editor` and substitute narrower roles.
