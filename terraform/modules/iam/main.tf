# Cross-cutting IAM that doesn't fit cleanly into a single resource module.
#
# Examples:
#   * a developer's user account needs `roles/run.viewer` to see service logs
#   * a Slack incident-bot SA needs `roles/monitoring.viewer`
#   * a billing budget for cost guardrails (prod)
#
# Most IAM lives next to the resource that owns it (e.g. `wif` module owns SA roles).
# This module is the escape hatch.

resource "google_project_iam_member" "extras" {
  for_each = {
    for idx, b in var.extra_project_bindings :
    "${b.role}:${b.member}" => b
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# --- Budget alert (prod cost guardrail) -------------------------------------

resource "google_billing_budget" "this" {
  count = var.budget_alert_email != "" && var.billing_account != "" && var.budget_amount_usd > 0 ? 1 : 0

  billing_account = var.billing_account
  display_name    = "deepCab-${var.env} monthly budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.budget_amount_usd))
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    disable_default_iam_recipients   = false
    monitoring_notification_channels = []
  }
}
