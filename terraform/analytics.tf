# -----------------------------------------------------------------------------
# Apigee Data Collectors for LLM Token & Model Analytics
# -----------------------------------------------------------------------------
resource "google_apigee_data_collector" "model_name" {
  org_id            = google_apigee_organization.org.id
  data_collector_id = "dc_model_name"
  description       = "LLM target model name (e.g., gemini-3.6-flash)"
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
  triggers_replace = [
    google_apigee_organization.org.name,
    var.custom_report_name,
  ]

  input = {
    org          = google_apigee_organization.org.name
    report_name  = var.custom_report_name
    display_name = "LLM Token Consumption Report"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      TMP_LIST="$(mktemp)"
      TMP_BODY="$(mktemp)"
      trap 'rm -f "$TMP_LIST" "$TMP_BODY"' EXIT
      TOKEN="$${GOOGLE_OAUTH_ACCESS_TOKEN:-$(gcloud auth print-access-token 2>/dev/null || gcloud auth application-default print-access-token)}"
      URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports"
      curl -4 -sf --retry 3 --retry-delay 5 -H "Authorization: Bearer $TOKEN" "$URL?expand=true" -o "$TMP_LIST"
      EXISTING_ID=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(next((r["name"] for r in d.get("qualifier",[]) if r.get("displayName")==sys.argv[2] or r.get("name")==sys.argv[3]), ""))' "$TMP_LIST" "${self.input.display_name}" "${self.input.report_name}")
      REPORT_ID="$${EXISTING_ID:-${self.input.report_name}}"
      python3 -c 'import json,sys; json.dump({"name":sys.argv[2],"displayName":sys.argv[3],"metrics":[{"name":"dc_prompt_token_count","function":"sum"},{"name":"dc_candidates_token_count","function":"sum"},{"name":"dc_total_token_count","function":"sum"}],"dimensions":["dc_model_name","api_product","developer_app"],"chartType":"line"}, open(sys.argv[1],"w"))' "$TMP_BODY" "$REPORT_ID" "${self.input.display_name}"
      if [ -n "$EXISTING_ID" ]; then
        curl -4 -sf --retry 3 --retry-delay 5 -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @"$TMP_BODY" "$URL/$EXISTING_ID" >/dev/null
      else
        curl -4 -sf --retry 3 --retry-delay 5 -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @"$TMP_BODY" "$URL" >/dev/null
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TMP_LIST="$(mktemp)"
      trap 'rm -f "$TMP_LIST"' EXIT
      TOKEN="$${GOOGLE_OAUTH_ACCESS_TOKEN:-$(gcloud auth print-access-token 2>/dev/null || gcloud auth application-default print-access-token 2>/dev/null || true)}"
      if [ -n "$TOKEN" ]; then
        URL="https://apigee.googleapis.com/v1/organizations/${self.input.org}/reports"
        if curl -4 -sf -H "Authorization: Bearer $TOKEN" "$URL?expand=true" -o "$TMP_LIST" 2>/dev/null; then
          EXISTING_IDS=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(r["name"] for r in d.get("qualifier",[]) if r.get("displayName")==sys.argv[2] or r.get("name")==sys.argv[3]))' "$TMP_LIST" "${self.input.display_name}" "${self.input.report_name}" 2>/dev/null || true)
          for id in $EXISTING_IDS; do
            curl -4 -s -X DELETE -H "Authorization: Bearer $TOKEN" "$URL/$id" >/dev/null || true
          done
        fi
      fi
    EOT
  }

  depends_on = [
    google_apigee_instance_attachment.env,
    google_apigee_data_collector.model_name,
    google_apigee_data_collector.prompt_token_count,
    google_apigee_data_collector.candidates_token_count,
    google_apigee_data_collector.total_token_count,
    google_apigee_environment_addons_config.analytics,
  ]
}
