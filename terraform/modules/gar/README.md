# Module: `gar`

Provisions a single Artifact Registry **Docker** repository named `deepcab` (configurable).
Used by the 001 image-build CI to push, and by the `cloud_run` / `cloud_run_job` modules in 002 to reference.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | — | GCP project ID. |
| `region` | `string` | — | Region (e.g. `us-central1`). |
| `repo_id` | `string` | `"deepcab"` | Repository short name. |
| `description` | `string` | `"deepCab container images …"` | Free-form description. |
| `labels` | `map(string)` | `{}` | Labels applied to the repo. |

## Outputs

| Name | Description |
|---|---|
| `repo_id` | Short name of the repo. |
| `repo_url` | Image URL prefix: `${region}-docker.pkg.dev/${project_id}/${repo_id}`. |
| `repo_name` | Fully-qualified GAR resource name. |

## Cleanup policies

The module ships with two opinionated policies:

- `keep-tagged-recent` — keeps the 10 most recent tagged versions per package (`api`, `retrain`).
- `delete-untagged` — deletes untagged blobs older than 7 days.

These are safe defaults for a learning project; tune to taste.
