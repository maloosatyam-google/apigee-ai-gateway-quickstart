# Dedicated Service Account for the Apigee AI Gateway proxy runtime
resource "google_service_account" "apigee_proxy" {
  account_id   = var.proxy_sa_id
  display_name = "Apigee AI Gateway Proxy Runtime SA"
  description  = "Used by the ai-gateway-v1 Apigee proxy to call Vertex AI, Model Armor, and Cloud Logging."
  depends_on   = [google_project_service.apis]
}

locals {
  proxy_sa_roles = toset([
    "roles/aiplatform.user",
    "roles/modelarmor.user",
    "roles/logging.logWriter",
  ])
}

resource "google_project_iam_member" "apigee_proxy_roles" {
  for_each = local.proxy_sa_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.apigee_proxy.email}"
}

# Allow the Apigee Google-managed Service Agent to mint tokens / act as our proxy SA
resource "google_project_service_identity" "apigee" {
  provider = google-beta
  project  = var.project_id
  service  = google_project_service.apis["apigee.googleapis.com"].service
}

resource "google_service_account_iam_member" "apigee_agent_token_creator" {
  service_account_id = google_service_account.apigee_proxy.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.apigee.member
}
