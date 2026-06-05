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
  default     = "deepcab-website"
}

variable "image" {
  description = "Docker image including tag (nginx-served Vite bundle). Overridden by 003 CI on each release."
  type        = string
}

variable "service_account_email" {
  description = "Runtime SA email — from the wif module. Shared with api/job services."
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
  default     = "256Mi"
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
  default     = 200
}

variable "timeout_seconds" {
  description = "Per-request timeout."
  type        = number
  default     = 30
}

variable "container_port" {
  description = "Container port (nginx)."
  type        = number
  default     = 80
}

variable "allow_unauthenticated" {
  description = "If true, grant `roles/run.invoker` to allUsers (public site)."
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Cloud Run ingress."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}
