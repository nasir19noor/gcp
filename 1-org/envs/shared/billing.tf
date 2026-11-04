# A monthly budget on the whole billing account. Budgets only alert; they
# never stop spending.

resource "google_monitoring_notification_channel" "billing_email" {
  project      = google_project.common["billing"].project_id
  display_name = "Budget alerts (${local.org.essential_contact})"
  type         = "email"
  labels = {
    email_address = local.org.essential_contact
  }

  depends_on = [google_project_service.common]
}

resource "google_billing_budget" "billing_account" {
  billing_account = local.gcp.billing_account
  display_name    = "${local.gcp.domain} monthly"

  amount {
    specified_amount {
      currency_code = local.org.budget.currency
      units         = tostring(local.org.budget.amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = local.org.budget.alert_at
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  # And when the month is forecast to go over.
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.billing_email.id]
    disable_default_iam_recipients   = false # billing account admins are e-mailed too
  }
}
