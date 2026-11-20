# -----------------------------------------------------------------------------
# Apigee Data Collectors for LLM Token & Model Analytics
# -----------------------------------------------------------------------------
resource "google_apigee_data_collector" "model_name" {
  org_id            = google_apigee_organization.org.id
  data_collector_id = "dc_model_name"
  description       = "LLM target model name (e.g., gemini-2.5-flash)"
  type              = "STRING"
}

resource "google_apigee_data_collector" "prompt_token_count" {
  org_id            = google_apigee_organization.org.id
  data_collector_id = "dc_prompt_token_count"
  description       = "Input prompt token count reported by Vertex AI"
  type              = "INTEGER"
}

resource "google_apigee_data_collector" "candidates_token_count" {
  org_id            = google_apigee_organization.org.id
  data_collector_id = "dc_candidates_token_count"
  description       = "Output candidate token count reported by Vertex AI"
  type              = "INTEGER"
}

resource "google_apigee_data_collector" "total_token_count" {
  org_id            = google_apigee_organization.org.id
  data_collector_id = "dc_total_token_count"
  description       = "Total token count (prompt + candidates) reported by Vertex AI"
  type              = "INTEGER"
}

# -----------------------------------------------------------------------------
# Custom Report for LLM Token Consumption (via Apigee Reports REST API)
# -----------------------------------------------------------------------------
resource "terraform_data" "llm_consumption_report" {
  input = {
    org         = google_apigee_organization.org.name
    report_name = var.custom_report_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      TOKEN="$(gcloud auth print-access-token)"
      URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports"
      PAYLOAD=$(cat <<'JSON'
      {
        "name": "${self.input.report_name}",
        "displayName": "LLM Token Consumption Report",
        "metrics": [
          {"name": "dc_prompt_token_count", "function": "sum"},
          {"name": "dc_candidates_token_count", "function": "sum"},
          {"name": "dc_total_token_count", "function": "sum"}
        ],
        "dimensions": ["dc_model_name", "api_product", "developer_app"],
        "chartType": "line"
      }
      JSON
      )
      CODE=$(curl -s -o /tmp/apigee_report_resp.json -w "%%{http_code}" -H "Authorization: Bearer $TOKEN" "$URL/${self.input.report_name}")
      if [ "$CODE" = "200" ]; then
        curl -sf -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL/${self.input.report_name}" >/dev/null
      else
        curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL" >/dev/null
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TOKEN="$(gcloud auth print-access-token 2>/dev/null || true)"
      if [ -n "$TOKEN" ]; then
        curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
          "https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports/${self.input.report_name}" >/dev/null || true
      fi
    EOT
  }

  depends_on = [
    google_apigee_data_collector.model_name,
    google_apigee_data_collector.prompt_token_count,
    google_apigee_data_collector.candidates_token_count,
    google_apigee_data_collector.total_token_count,
    google_apigee_environment_addons_config.analytics,
  ]
}
