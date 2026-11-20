output "apigee_org" {
  description = "Apigee organization name."
  value       = google_apigee_organization.org.name
}

output "apigee_environment" {
  description = "Primary Apigee environment name."
  value       = local.primary_env
}

output "apigee_sa_email" {
  description = "Dedicated Service Account used by the ai-gateway-v1 proxy."
  value       = google_service_account.apigee_proxy.email
}

output "model_armor_prompt_template" {
  description = "Model Armor template resource name for user prompt sanitization."
  value       = google_model_armor_template.sanitize_user_prompt.name
}

output "model_armor_response_template" {
  description = "Model Armor template resource name for model response sanitization."
  value       = google_model_armor_template.sanitize_model_response.name
}

output "gateway_host" {
  description = "Hostname for the primary Apigee environment group."
  value       = local.hostnames[local.env_group_of[local.primary_env]][0]
}

output "gateway_url" {
  description = "Base URL for the deployed AI Gateway proxy."
  value       = "https://${local.hostnames[local.env_group_of[local.primary_env]][0]}/ai/v1"
}

output "ingress_ip" {
  description = "External Load Balancer IP (routing=external) or internal PSC IP (routing=internal)."
  value       = local.lb_ip
}

output "api_key" {
  description = "Consumer key for the sample developer app."
  value       = google_apigee_developer_app.ai_app.credentials[0].consumer_key
  sensitive   = true
}

output "custom_report_name" {
  description = "Name of the Apigee custom report for LLM token consumption."
  value       = var.custom_report_name
}

output "smoke_test_command" {
  description = "Sample curl command to test the AI Gateway."
  value       = <<-EOT
    curl -sS -X POST \
      "https://${local.hostnames[local.env_group_of[local.primary_env]][0]}/ai/v1/models/${var.gemini_model}:generateContent" \
      -H "Content-Type: application/json" \
      -H "x-apikey: $(terraform -chdir=terraform output -raw api_key)" \
      -d '{"contents":[{"role":"user","parts":[{"text":"Explain Apigee AI Gateway in one sentence."}]}]}'
  EOT
}
