variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the Cloud SQL instance."
  type        = string
}

variable "env" {
  description = "Environment short name (dev/staging/prod)."
  type        = string
}

variable "instance_name" {
  description = "Cloud SQL instance name (must be globally unique within the project)."
  type        = string
  default     = "deepcab-mlflow"
}

variable "tier" {
  description = "Machine tier. dev=db-f1-micro, staging=db-g1-small, prod=db-custom-2-4096."
  type        = string
  default     = "db-f1-micro"
}

variable "activation_policy" {
  description = "ALWAYS = running (billed per hour). NEVER = stopped (only storage billed, ~$1/mo). Flip via the showcase_mode var in envs/dev/main.tf."
  type        = string
  default     = "ALWAYS"
  validation {
    condition     = contains(["ALWAYS", "NEVER", "ON_DEMAND"], var.activation_policy)
    error_message = "activation_policy must be ALWAYS, NEVER, or ON_DEMAND."
  }
}

variable "database_version" {
  description = "Postgres version."
  type        = string
  default     = "POSTGRES_16"
}

variable "disk_size_gb" {
  description = "Initial data disk size in GB. Autoresize is enabled."
  type        = number
  default     = 10
}

variable "deletion_protection" {
  description = "Block accidental destroy via `terraform destroy`. ON in prod, OFF in dev."
  type        = bool
  default     = true
}

variable "use_private_ip" {
  description = "If true, use private IP only and require var.private_network. If false, public IP with authorized networks."
  type        = bool
  default     = true
}

variable "private_network" {
  description = "VPC self_link for private IP. Required when use_private_ip = true."
  type        = string
  default     = ""
}

variable "private_services_connection" {
  description = "Dependency on the service-networking connection from the VPC module (force ordering)."
  type        = string
  default     = ""
}

variable "authorized_networks" {
  description = "List of CIDR blocks (with display names) allowed when use_private_ip = false."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "databases" {
  description = "Logical databases to create inside the instance."
  type        = list(string)
  default     = ["mlflow"]
}

variable "users" {
  description = "Database users to create. Passwords are randomized; surface them via the `mlflow-db-password` secret."
  type        = list(string)
  default     = ["mlflow"]
}

variable "enable_prefect_db" {
  description = "Convenience flag — when true, adds `prefect` to databases."
  type        = bool
  default     = false
}

variable "backup_enabled" {
  description = "Enable automated daily backups."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the instance."
  type        = map(string)
  default     = {}
}
