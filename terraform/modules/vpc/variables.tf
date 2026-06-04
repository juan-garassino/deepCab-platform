variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Primary region."
  type        = string
}

variable "env" {
  description = "Environment short name."
  type        = string
}

variable "enabled" {
  description = "If false, the module is a no-op. Gate so dev can skip VPC entirely."
  type        = bool
  default     = true
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "deepcab-vpc"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR (used by Cloud Run direct VPC egress / GKE nodes)."
  type        = string
  default     = "10.20.0.0/20"
}

variable "private_services_cidr" {
  description = "CIDR reserved for Google-managed services (Cloud SQL private IP, etc.)."
  type        = string
  default     = "10.30.0.0/16"
}

variable "enable_nat" {
  description = "Provision a Cloud NAT for outbound internet from private workloads."
  type        = bool
  default     = true
}
