variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "env" {
  type = string
}

variable "service_name" {
  type    = string
  default = "deepcab-mlflow"
}

variable "image" {
  type    = string
  default = "ghcr.io/mlflow/mlflow:v2.16.2"
}

variable "service_account_email" {
  type        = string
  description = "Runtime SA email; must have cloudsql.client + storage.objectAdmin on the artifacts bucket + secretAccessor on db_password_secret."
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 2
}

variable "container_concurrency" {
  type    = number
  default = 40
}

variable "timeout_seconds" {
  type    = number
  default = 60
}

variable "container_port" {
  type    = number
  default = 5000
}

variable "cloudsql_instance" {
  type        = string
  description = "Cloud SQL connection name (PROJECT:REGION:INSTANCE)"
}

variable "db_user" {
  type    = string
  default = "mlflow"
}

variable "db_name" {
  type    = string
  default = "mlflow"
}

variable "db_password_secret" {
  type        = string
  description = "Secret Manager secret ID holding the MLflow DB password."
  default     = "mlflow-db-password"
}

variable "artifacts_bucket" {
  type        = string
  description = "GCS bucket name (without gs:// prefix) for MLflow run artifacts."
}

variable "allow_unauthenticated" {
  type    = bool
  default = true
}

variable "ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_ALL"
}

variable "labels" {
  type    = map(string)
  default = {}
}
