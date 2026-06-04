# Module: `storage`

Three GCS buckets per environment:

| Bucket | Purpose | Lifecycle |
|---|---|---|
| `${prefix}-mlflow-artifacts-${env}` | MLflow artifact store | Move to NEARLINE after N days; keep ≤5 versions |
| `${prefix}-models-${env}` | Trained model artifacts written by the retrain job | Move to COLDLINE after 90 days |
| `${prefix}-tfstate-${env}` | Terraform remote state (versioned) | Keep ≤30 versions, age ≥30 days |

> **Chicken-and-egg note:** the `tfstate` bucket is created *manually* during
> first-time bootstrap (see `../../../docs/RUNBOOK.md`), then imported into
> state. The resource declaration here ensures the bucket stays drift-managed.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | |
| `region` | `string` | — | Single-region location. |
| `env` | `string` | — | `dev`/`staging`/`prod`. |
| `name_prefix` | `string` | `"deepcab"` | Bucket name prefix. |
| `force_destroy` | `bool` | `false` | Allow `terraform destroy` even with objects present (dev only). |
| `mlflow_artifacts_lifecycle_days` | `number` | `30` | Days before mlflow artifacts go NEARLINE. |
| `models_archive_days` | `number` | `90` | Days before models go COLDLINE. |
| `labels` | `map(string)` | `{}` | Labels applied to every bucket. |

## Outputs

| Name | Description |
|---|---|
| `mlflow_artifacts_bucket` / `mlflow_artifacts_url` | The MLflow bucket. |
| `models_bucket` / `models_url` | The trained-models bucket. |
| `tfstate_bucket` | The state bucket name. |
