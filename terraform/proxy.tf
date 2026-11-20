locals {
  proxy_src_dir   = "${path.module}/../apigee/proxies/ai-gateway-v1/apiproxy"
  proxy_build_dir = "${path.module}/.build/ai-gateway-v1"
  proxy_files     = fileset(local.proxy_src_dir, "**")
}

resource "local_file" "proxy_files" {
  for_each = local.proxy_files
  filename = "${local.proxy_build_dir}/apiproxy/${each.value}"
  content = replace(
    replace(file("${local.proxy_src_dir}/${each.value}"), "__GCP_PROJECT_ID__", var.project_id),
    "__GCP_REGION__",
    var.region
  )
}

data "archive_file" "ai_gateway_proxy" {
  type        = "zip"
  source_dir  = local.proxy_build_dir
  output_path = "${path.module}/.build/ai-gateway-v1.zip"
  depends_on  = [local_file.proxy_files]
}

resource "google_apigee_api" "ai_gateway" {
  org_id         = google_apigee_organization.org.id
  name           = "ai-gateway-v1"
  config_bundle  = data.archive_file.ai_gateway_proxy.output_path
  detect_md5hash = data.archive_file.ai_gateway_proxy.output_md5
}

resource "google_apigee_api_deployment" "ai_gateway" {
  for_each        = var.environments
  org_id          = google_apigee_organization.org.id
  environment     = google_apigee_environment.env[each.key].name
  proxy_id        = google_apigee_api.ai_gateway.name
  revision        = google_apigee_api.ai_gateway.latest_revision_id
  service_account = google_service_account.apigee_proxy.email

  depends_on = [
    google_apigee_instance_attachment.env,
    google_apigee_envgroup_attachment.env,
    google_apigee_data_collector.model_name,
    google_apigee_data_collector.prompt_token_count,
    google_apigee_data_collector.candidates_token_count,
    google_apigee_data_collector.total_token_count,
    google_model_armor_template.sanitize_user_prompt,
    google_model_armor_template.sanitize_model_response,
    google_project_iam_member.apigee_proxy_roles,
    google_service_account_iam_member.apigee_agent_token_creator,
  ]
}
