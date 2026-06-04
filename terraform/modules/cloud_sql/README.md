# Module: `cloud_sql`

Cloud SQL for Postgres 16, sized per-env:

| Env | Tier | Availability | Backup retention |
|---|---|---|---|
| dev | `db-f1-micro` | ZONAL | 7 days |
| staging | `db-g1-small` | ZONAL | 7 days |
| prod | `db-custom-2-4096` | REGIONAL + PITR | 14 days |

Two operating modes:

- **Private IP** (default): requires `vpc` module's `private_services_connection`.
- **Public IP**: pass `use_private_ip = false` + `authorized_networks` (dev-only escape hatch).

## Logical layout

- One instance per env
- Databases: `mlflow` (always), `prefect` (gated by `enable_prefect_db`)
- One Postgres user per name in `var.users` (defaults to `["mlflow"]`); passwords are
  random-generated via `random_password` and surfaced as a sensitive map output.

> **After first apply:** copy the generated password into the `mlflow-db-password`
> secret (`gcloud secrets versions add mlflow-db-password --data-file=-`).
> The runtime SA reads it from Secret Manager — TF state is not the runtime source.

## Inputs

See `variables.tf`. Notable:

| Name | Default |
|---|---|
| `tier` | `db-f1-micro` |
| `deletion_protection` | `true` (override to `false` in dev) |
| `use_private_ip` | `true` |
| `databases` | `["mlflow"]` |
| `enable_prefect_db` | `false` |

## Outputs

| Name | Description |
|---|---|
| `instance_name` / `connection_name` | Use connection_name with Cloud SQL Proxy / Cloud Run integration. |
| `private_ip_address` / `public_ip_address` / `host` | Network handles. |
| `database_names` | List of created DBs. |
| `user_passwords` | `sensitive` map of generated passwords (rotate via Secret Manager). |
