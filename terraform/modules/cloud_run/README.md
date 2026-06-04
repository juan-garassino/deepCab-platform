# Module: `cloud_run`

Provisions the `deepcab-api` Cloud Run **v2** service. Owns the **service shape**
(CPU/memory/scale/env/IAM/probes). The 001-deepCab-api CI does image-only updates
via `gcloud run services update --image=...`; this module's `lifecycle.ignore_changes`
keeps TF from reverting those.

## Inputs (highlights)

| Name | Default | Notes |
|---|---|---|
| `image` | — required | Initial image. Overridden by 001 CI on each release. |
| `service_account_email` | — required | Runtime SA from `wif` module. |
| `cpu` / `memory` | `1` / `512Mi` | |
| `min_instances` / `max_instances` | `0` / `4` | |
| `container_concurrency` | `80` | |
| `timeout_seconds` | `60` | |
| `env_vars` | `{}` | Plain values: `APP_ENV`, `MLFLOW_TRACKING_URI`, etc. |
| `secret_env_vars` | `{}` | `{ENV_VAR = secret_id}` — read from Secret Manager `latest`. |
| `cloudsql_instances` | `[]` | List of connection names — adds `/cloudsql` socket. |
| `allow_unauthenticated` | `true` | Public service. |
| `ingress` | `INGRESS_TRAFFIC_ALL` | Tighten with `INTERNAL_ONLY` if fronting via LB. |

## Probes

Startup + liveness against `/healthz` on the container port (default 8000) —
mirrors `cloud-manifests/cloud-run/service.yaml`.

## Outputs

| Name | Description |
|---|---|
| `service_name` | Pass to `gcloud run services update --image=...`. |
| `service_url` | Stable HTTPS URL. |
| `location` / `latest_revision` | Operational handles. |

## Cross-repo contract

The 001 deploy workflow runs:
```bash
gcloud run services update ${TF_SERVICE_NAME} \
  --image=${GAR_REPO_URL}/api:${TAG} \
  --region=${REGION} --project=${PROJECT}
```

Nothing else. CPU/memory/env vars/IAM are TF's territory — change them by
editing the env's `main.tf`, opening a PR, getting a TF plan in CI, and merging.
