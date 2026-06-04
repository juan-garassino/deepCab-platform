# Module: `cloud_run_job`

Cloud Run **Job** running the daily retrain: same image as the API service,
entrypoint `python -m deepCab.training.train`. Fired by the `scheduler` module.

## Inputs (highlights)

| Name | Default |
|---|---|
| `image` | — required (typically `<gar.repo_url>/api:latest`) |
| `service_account_email` | — required (runtime SA) |
| `command` | `["python"]` |
| `args` | `["-m", "deepCab.training.train", "backend=tf_mlp", "data=full"]` |
| `cpu` / `memory` | `4` / `8Gi` |
| `task_timeout_seconds` | `3600` |
| `max_retries` | `1` |
| `cloudsql_instances` | `[]` |
| `scheduler_sa_email` | — required (granted `run.invoker` on this job) |

## Outputs

| Name | Description |
|---|---|
| `job_name` / `job_id` | Handles. |
| `location` | Region. |
| `execute_uri` | Pass to the `scheduler` module's `target_uri`. |

## Image update contract

Identical to `cloud_run`: TF owns the spec; 001 CI calls
`gcloud run jobs update deepcab-retrain --image=...` on each release.
The `lifecycle.ignore_changes` on `image` keeps plans clean.
