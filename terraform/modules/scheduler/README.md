# Module: `scheduler`

Cloud Scheduler HTTP job that fires the Cloud Run **Job**. Replaces the
imperative `001/infra/gcp/scheduler/bootstrap.sh`.

## Inputs

| Name | Default |
|---|---|
| `schedule_name` | `deepcab-retrain-daily` |
| `cron_schedule` | `0 2 * * *` (02:00 UTC daily) |
| `time_zone` | `Etc/UTC` |
| `target_uri` | — required (pass `cloud_run_job.execute_uri`) |
| `service_account_email` | — required (the scheduler SA from `wif`) |
| `attempt_deadline` | `1800s` |
| `retry_count` | `0` (Job has its own `max_retries`) |
| `paused` | `false` |

## OAuth target

The scheduler signs each request with an OAuth access token minted via the
scheduler SA. Cloud Run validates this against the Job's `run.invoker` policy
(granted in the `cloud_run_job` module).

## Outputs

| Name | Description |
|---|---|
| `schedule_name` | Cloud Scheduler job name. |
| `schedule_id` | Full resource ID. |
| `next_run_estimate` | The configured cron expression (the actual next-run timestamp is dynamic). |
