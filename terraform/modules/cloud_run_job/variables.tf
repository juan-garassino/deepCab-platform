variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run Job."
  type        = string
}

variable "env" {
  description = "Environment short name."
  type        = string
}

variable "job_name" {
  description = "Cloud Run Job name."
  type        = string
  default     = "deepcab-retrain"
}

variable "image" {
  description = "Image to run. Same image as cloud_run, just a different entry."
  type        = string
}

variable "service_account_email" {
  description = "Runtime SA email — from the wif module."
  type        = string
}

variable "command" {
  description = "Container entrypoint."
  type        = list(string)
  default     = ["python"]
}

variable "args" {
  description = "Arguments to the entrypoint."
  type        = list(string)
  default = [
    "-m",
    "deepCab.training.train",
    "backend=tf_mlp",
    "data=full",
  ]
}

variable "cpu" {
  description = "Container CPU."
  type        = string
  default     = "4"
}

variable "memory" {
  description = "Container memory."
  type        = string
  default     = "8Gi"
}

variable "task_timeout_seconds" {
  description = "Per-task wall-clock timeout."
  type        = number
  default     = 3600
}

variable "max_retries" {
  description = "Per-task retry budget."
  type        = number
  default     = 1
}

variable "parallelism" {
  description = "How many tasks run in parallel inside one Job execution."
  type        = number
  default     = 1
}

variable "task_count" {
  description = "Number of tasks per execution."
  type        = number
  default     = 1
}

variable "env_vars" {
  description = "Plain (non-secret) env vars."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Env vars sourced from Secret Manager."
  type        = map(string)
  default     = {}
}

variable "cloudsql_instances" {
  description = "Optional Cloud SQL connections."
  type        = list(string)
  default     = []
}

variable "scheduler_sa_email" {
  description = "Scheduler SA email — granted run.invoker on this job so Cloud Scheduler can run it."
  type        = string
}

variable "labels" {
  description = "Labels applied to the job."
  type        = map(string)
  default     = {}
}
