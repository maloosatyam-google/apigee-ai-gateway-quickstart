# -----------------------------------------------------------------------------
# API Product with LLM Operation Group & LLM Token Quota
# (Managed via Apigee REST API because google_apigee_api_product does not yet
#  expose llmOperationGroup / llmTokenQuota in the Terraform provider.)
# -----------------------------------------------------------------------------
resource "terraform_data" "ai_gateway_product" {
  triggers_replace = [
    google_apigee_organization.org.name,
    var.api_product_name,
    jsonencode(keys(var.environments)),
    var.gemini_model,
    tostring(var.llm_token_quota_limit),
    tostring(var.llm_token_quota_interval),
    var.llm_token_quota_time_unit,
  ]

  input = {
    org          = google_apigee_organization.org.name
    product_name = var.api_product_name
    environments = jsonencode(keys(var.environments))
    gemini_model = var.gemini_model
    quota_limit  = tostring(var.llm_token_quota_limit)
    quota_int    = tostring(var.llm_token_quota_interval)
    quota_unit   = var.llm_token_quota_time_unit
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      TMP_RESP="$(mktemp)"
      trap 'rm -f "$TMP_RESP"' EXIT
      TOKEN="$${GOOGLE_OAUTH_ACCESS_TOKEN:-$(gcloud auth print-access-token 2>/dev/null || gcloud auth application-default print-access-token)}"
      URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/apiproducts"
      PAYLOAD=$(cat <<JSON
      {
        "name": "${self.input.product_name}",
        "displayName": "AI Gateway Product (${self.input.gemini_model})",
        "description": "API Product for ai-gateway-v1 with LLM Token Quota (${self.input.quota_limit} tokens / ${self.input.quota_int} ${self.input.quota_unit}).",
        "approvalType": "auto",
        "attributes": [
          {"name": "access", "value": "private"}
        ],
        "environments": ${self.input.environments},
        "llmOperationGroup": {
          "operationConfigs": [
            {
              "apiSource": "ai-gateway-v1",
              "llmOperations": [
                {
                  "resource": "/models/${self.input.gemini_model}:*",
                  "methods": ["POST"],
                  "model": "${self.input.gemini_model}"
                }
              ],
              "llmTokenQuota": {
                "limit": "${self.input.quota_limit}",
                "interval": "${self.input.quota_int}",
                "timeUnit": "${self.input.quota_unit}"
              }
            }
          ]
        }
      }
      JSON
      )
      CODE=$(curl -4 -s --retry 3 --retry-delay 5 -o "$TMP_RESP" -w "%%{http_code}" -H "Authorization: Bearer $TOKEN" "$URL/${self.input.product_name}")
      if [ "$CODE" = "200" ]; then
        curl -4 -sf --retry 3 --retry-delay 5 -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL/${self.input.product_name}" >/dev/null
      else
        curl -4 -sf --retry 3 --retry-delay 5 -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL" >/dev/null
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TOKEN="$${GOOGLE_OAUTH_ACCESS_TOKEN:-$(gcloud auth print-access-token 2>/dev/null || gcloud auth application-default print-access-token 2>/dev/null || true)}"
      if [ -n "$TOKEN" ]; then
        curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
          "https://apigee.googleapis.com/v1/organizations/${self.input.org}/apiproducts/${self.input.product_name}" >/dev/null || true
      fi
    EOT
  }

  depends_on = [google_apigee_api_deployment.ai_gateway]
}

# -----------------------------------------------------------------------------
# Developer & Developer App
# -----------------------------------------------------------------------------
resource "google_apigee_developer" "ai_dev" {
  org_id     = google_apigee_organization.org.id
  email      = var.developer_email
  first_name = var.developer_first_name
  last_name  = var.developer_last_name
  user_name  = split("@", var.developer_email)[0]

  depends_on = [google_apigee_instance_attachment.env]
}

resource "google_apigee_developer_app" "ai_app" {
  org_id          = google_apigee_organization.org.id
  developer_email = google_apigee_developer.ai_dev.email
  name            = var.developer_app_name
  callback_url    = "https://example.com/callback"
  api_products    = [var.api_product_name]

  depends_on = [terraform_data.ai_gateway_product]
}
