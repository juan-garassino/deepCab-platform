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
  default = "deepcab-status"
}

variable "image" {
  type    = string
  default = "docker.io/louislam/uptime-kuma:1"
}

variable "service_account_email" {
  type        = string
  description = "Runtime SA email. Needs storage.objectAdmin on the state bucket for SQLite persistence via gcsfuse."
}

variable "state_bucket" {
  type        = string
  description = "GCS bucket name (without gs://) to back the Uptime Kuma SQLite DB via gcsfuse mount."
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type        = number
  default     = 0
  description = "Set 0 between demos (probes pause, $0/mo). Set 1 during showcase (~$5/mo)."
}

variable "max_instances" {
  type    = number
  default = 1
}

variable "container_concurrency" {
  type    = number
  default = 80
}

variable "timeout_seconds" {
  type    = number
  default = 30
}

variable "container_port" {
  type    = number
  default = 3001
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
