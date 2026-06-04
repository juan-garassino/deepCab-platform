variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Scheduler region — typically same as the Cloud Run Job."
  type        = string
}

variable "env" {
  description = "Environment short name."
  type        = string
}

variable "schedule_name" {
  description = "Cloud Scheduler job name."
  type        = string
  default     = "deepcab-retrain-daily"
}

variable "description" {
  description = "Free-form description."
  type        = string
  default     = "Daily deepcab retrain — fires Cloud Run Job deepcab-retrain."
}

variable "cron_schedule" {
  description = "Cron expression (UTC by default)."
  type        = string
  default     = "0 2 * * *"
}

variable "time_zone" {
  description = "IANA timezone."
  type        = string
  default     = "Etc/UTC"
}

variable "target_uri" {
  description = "HTTP URI to call. Typically the `execute_uri` output from the cloud_run_job module."
  type        = string
}

variable "service_account_email" {
  description = "Scheduler SA email — used to mint the OAuth token attached to the request."
  type        = string
}

variable "attempt_deadline" {
  description = "Per-attempt deadline."
  type        = string
  default     = "1800s"
}

variable "retry_count" {
  description = "Cloud Scheduler retries on top of whatever max_retries the Job already does."
  type        = number
  default     = 0
}

variable "paused" {
  description = "If true, the schedule is created but paused. Useful in dev."
  type        = bool
  default     = false
}
