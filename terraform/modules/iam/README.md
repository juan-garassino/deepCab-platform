# Module: `iam`

Cross-cutting IAM bindings and a billing-budget escape hatch.

## Use cases

- Grant a developer's user account `roles/run.viewer`
- Grant a Slack incident-bot SA `roles/monitoring.viewer`
- Provision a billing budget alert (prod cost guardrail)

Most IAM should live next to the resource that owns it (e.g. `wif` for SA roles,
`secret_manager` for secret-access bindings). Use this module only when no resource module is a natural home.

## Inputs

| Name | Description |
|---|---|
| `project_id` | GCP project ID. |
| `env` | Environment short name. |
| `extra_project_bindings` | List of `{role, member}`. |
| `budget_amount_usd` | If > 0 and email + billing_account set, creates a billing budget. |
| `budget_alert_email` | Recipient email for budget threshold alerts. |
| `billing_account` | Billing account ID (e.g. `0X0X0X-0X0X0X-0X0X0X`). |

## Outputs

| Name | Description |
|---|---|
| `extras_count` | Number of extra bindings provisioned. |
| `budget_enabled` | Whether a budget was created. |
