# Module: `secret_manager`

Declares the **secret containers** the deepCab stack expects to find at runtime.
Values are populated out-of-band after first apply — TF never holds the literals
(state lives in GCS and is read by CI).

## Default secret IDs

| ID | Purpose |
|---|---|
| `slack-webhook-url` | Slack notifications from deploy / drift workflows |
| `openai-api-key` | Used by `deepCab.agent.*` |
| `deepcab-api-key` | X-API-Key gating `/train` and `/agent/improve` |
| `mlflow-db-password` | MLflow Cloud SQL password (read by the API + retrain job) |

Override `var.secret_ids` to add/remove.

## Populate after `terraform apply`

```bash
echo -n "https://hooks.slack.com/..." | gcloud secrets versions add slack-webhook-url --data-file=- --project=$PROJECT
echo -n "sk-..."                       | gcloud secrets versions add openai-api-key   --data-file=- --project=$PROJECT
openssl rand -hex 32 | tr -d '\n'      | gcloud secrets versions add deepcab-api-key  --data-file=- --project=$PROJECT
openssl rand -base64 32 | tr -d '=\n'  | gcloud secrets versions add mlflow-db-password --data-file=- --project=$PROJECT
```

## Inputs / Outputs

See `variables.tf` / `outputs.tf`. The module binds `roles/secretmanager.secretAccessor`
on every secret to the runtime SA passed in (`runtime_sa_email`).
