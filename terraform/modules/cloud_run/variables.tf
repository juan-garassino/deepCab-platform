variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run service."
  type        = string
}

variable "env" {
  description = "Environment short name."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "deepcab-api"
}

variable "image" {
  description = "Docker image including tag (e.g. us-central1-docker.pkg.dev/PROJECT/deepcab/api:latest). Overridden by 001 CI on each release."
  type        = string
}

variable "service_account_email" {
  description = "Runtime SA email — from the wif module."
  type        = string
}

variable "cpu" {
  description = "Container CPU."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Container memory."
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = "Minimum number of warm instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "container_concurrency" {
  description = "Max in-flight requests per instance."
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Per-request timeout."
  type        = number
  default     = 60
}

variable "container_port" {
  description = "Container port for the FastAPI app."
  type        = number
  default     = 8000
}

variable "env_vars" {
  description = "Plain (non-secret) env vars."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Env vars sourced from Secret Manager (`{ ENV_VAR = secret_id }`). Always uses the `latest` version."
  type        = map(string)
  default     = {}
}

variable "cloudsql_instances" {
  description = "Optional list of Cloud SQL connection names to mount via Cloud Run Cloud SQL integration."
  type        = list(string)
  default     = []
}

variable "allow_unauthenticated" {
  description = "If true, grant `roles/run.invoker` to allUsers (public service)."
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Cloud Run ingress (INGRESS_TRAFFIC_ALL | INGRESS_TRAFFIC_INTERNAL_ONLY | INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER)."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}
