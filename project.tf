resource "google_project" "my_project" {
  name       = var.project_name
  project_id = "${var.project_id}-${random_string.random.result}"
  org_id     = var.org_id
  billing_account = var.billing_account
}

resource "random_string" "random" {
  length = 8
  upper = false
  special = false
}

resource "google_pubsub_topic" "my_topic" {
    name = var.budget_pubsub_topic
    project = var.terraform_project_id
}

data "google_billing_account" "account" {
  provider = google-beta
  billing_account = var.billing_account
}

resource "google_billing_budget" "budget" {
  provider = google-beta
  billing_account = data.google_billing_account.account.id
  display_name = "Example Billing Budget"

  budget_filter {
    projects = ["projects/${google_project.my_project.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units = var.budget_limit
    }
  }

  threshold_rules {
      threshold_percent = var.threshold_percent
  }

  all_updates_rule {
      pubsub_topic = "projects/${var.terraform_project_id}/topics/${var.budget_pubsub_topic}"
  }

  depends_on = [google_pubsub_topic.my_topic]
}
