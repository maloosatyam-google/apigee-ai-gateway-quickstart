locals {
  required_apis = toset([
    "apigee.googleapis.com",
    "compute.googleapis.com",
    "aiplatform.googleapis.com",
    "modelarmor.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ])
}

resource "google_project_service" "apis" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
