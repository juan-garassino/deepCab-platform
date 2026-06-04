variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment short name."
  type        = string
}

variable "extra_project_bindings" {
  description = "Extra project-level IAM bindings that don't belong to a single resource module. Each entry has a `role` + `member`. Member is the full IAM-friendly identifier (e.g. `serviceAccount:foo@…`, `user:alice@…`, `group:…`)."
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "budget_alert_email" {
  description = "Email recipient for the project budget alert. Empty disables the budget."
  type        = string
  default     = ""
}

variable "budget_amount_usd" {
  description = "Monthly budget amount in USD. Alerts at 50/90/100% of this value."
  type        = number
  default     = 0
}

variable "billing_account" {
  description = "Billing account ID (e.g. 0X0X0X-0X0X0X-0X0X0X). Required when budget_alert_email is set."
  type        = string
  default     = ""
}
