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
  description       = "Total token count (prompt + candidates + thoughts) reported by Vertex AI"
  type              = "INTEGER"
}

# -----------------------------------------------------------------------------
# Custom Report for LLM Token Consumption (via Apigee Reports REST API)
# Note: Apigee X assigns a server-generated UUID to CustomReport.name on POST,
# so we look up existing reports via ?expand=true matching displayName.
# -----------------------------------------------------------------------------
resource "terraform_data" "llm_consumption_report" {
  input = {
    org          = google_apigee_organization.org.name
    report_name  = var.custom_report_name
    display_name = "LLM Token Consumption Report"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token)"
      URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports"
      EXISTING_ID=$(curl -sf -H "Authorization: Bearer $TOKEN" "$URL?expand=true" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for r in data.get("qualifier", []):
    if r.get("displayName") == "${self.input.display_name}" or r.get("name") == "${self.input.report_name}":
        print(r["name"])
        break
')
      REPORT_ID="$${EXISTING_ID:-${self.input.report_name}}"
      PAYLOAD=$(cat <<JSON
      {
        "name": "$REPORT_ID",
        "displayName": "${self.input.display_name}",
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
      if [ -n "$EXISTING_ID" ]; then
        curl -sf -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL/$EXISTING_ID" >/dev/null
      else
        curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL" >/dev/null
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token 2>/dev/null || true)"
      if [ -n "$TOKEN" ]; then
        URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports"
        EXISTING_IDS=$(curl -sf -H "Authorization: Bearer $TOKEN" "$URL?expand=true" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for r in data.get("qualifier", []):
        if r.get("displayName") == "${self.input.display_name}" or r.get("name") == "${self.input.report_name}":
            print(r["name"])
except Exception:
    pass
' || true)
        for id in $EXISTING_IDS; do
          curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "$URL/$id" >/dev/null || true
        done
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
