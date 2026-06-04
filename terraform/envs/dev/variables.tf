variable "project_id" {
  description = "GCP project ID for the dev environment."
  type        = string
}

variable "project_number" {
  description = "GCP project number (used in WIF principalSet identifiers)."
  type        = string
}

variable "region" {
  description = "Primary region."
  type        = string
  default     = "us-central1"
}

variable "gh_owner" {
  description = "GitHub owner (org/user) of both deepCab repos."
  type        = string
  default     = "juan-garassino"
}

variable "gh_api_repo" {
  description = "Name of the API repo (image builder)."
  type        = string
  default     = "deepCab"
}

variable "gh_platform_repo" {
  description = "Name of THIS platform repo."
  type        = string
  default     = "deepCab-platform"
}

variable "api_image" {
  description = "Initial API container image. Default = bootstrap placeholder; first real image lands after 001 CI runs."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "retrain_image" {
  description = "Initial retrain container image."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "mlflow_tracking_uri" {
  description = "URL of the MLflow tracking server reachable from Cloud Run."
  type        = string
  default     = "http://mlflow.dev.deepcab.com:5000"
}
