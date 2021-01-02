provider "google" {
  region  = "us-central1"
  zone    = "us-central1-c"
}

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
  display_name = var.budget_name

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

/*
resource "google_service_account" "service_account" {
  account_id   = var.service_account_id
  display_name = var.service_account_name
  project = var.terraform_project_id
}
*/


resource "google_storage_bucket" "bucket" {
  name = var.bucket_name
  project = var.terraform_project_id
}

resource "google_storage_bucket_object" "archive" {
  name   = var.function_code_filename
  bucket = google_storage_bucket.bucket.name
  source = var.function_code_source
}

resource "google_cloudfunctions_function" "function" {
  project     = var.terraform_project_id
  name        = var.function_name
  description = var.function_description
  runtime     = var.function_runtime

  available_memory_mb   = var.function_available_memory_mb
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = var.budget_pubsub_topic
  }
  timeout               = var.function_timeout
  entry_point           = var.function_entry_point

  // environment_variables = {
    // MY_ENV_VAR = "my-env-var-value"
  // }
}

/*
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = var.function_iam_role
  member = "serviceAccount:${google_service_account.service_account}"
}*/