#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

log()  { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "  \033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m[WARN]\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m[FAIL]\033[0m %s\n" "$*" >&2; exit 1; }

log "Checking prerequisites"
for cmd in gcloud terraform curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
  ok "$cmd found"
done

if [ ! -f "${TF_DIR}/terraform.tfvars" ]; then
  if [ -n "${GCP_PROJECT_ID:-}" ]; then
    log "Generating terraform/terraform.tfvars from environment variables"
    cat > "${TF_DIR}/terraform.tfvars" <<EOF
project_id = "${GCP_PROJECT_ID}"
region     = "${GCP_REGION:-us-central1}"
EOF
    ok "Created terraform/terraform.tfvars for project ${GCP_PROJECT_ID}"
  else
    fail "terraform/terraform.tfvars not found. Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and set project_id, or export GCP_PROJECT_ID."
  fi
fi

# Align Terraform credentials with the active gcloud CLI account when ADC is unset or logged into a different user
if [ -z "${GOOGLE_OAUTH_ACCESS_TOKEN:-}" ] && [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  CLI_ACCT="$(gcloud config get-value account 2>/dev/null || true)"
  ADC_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
  ADC_ACCT=""
  if [ -n "$ADC_TOKEN" ]; then
    ADC_ACCT="$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=${ADC_TOKEN}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('email',''))" 2>/dev/null || true)"
  fi
  if [ -n "$CLI_ACCT" ] && [ "$CLI_ACCT" != "$ADC_ACCT" ]; then
    warn "ADC account (${ADC_ACCT:-none}) differs from active gcloud account (${CLI_ACCT}); using gcloud CLI access token for Terraform."
    export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
  fi
fi

# Extract project_id from terraform.tfvars to bootstrap foundational APIs on brand-new projects
TF_PROJECT_ID="$(python3 -c '
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r"^\s*project_id\s*=\s*\"([^\"]+)\"", txt, re.M)
print(m.group(1) if m else "")
' "${TF_DIR}/terraform.tfvars")"

if [ -n "$TF_PROJECT_ID" ]; then
  log "Bootstrapping Service Usage & Cloud Resource Manager APIs on ${TF_PROJECT_ID}"
  gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com --project="${TF_PROJECT_ID}"
  ok "Bootstrap APIs enabled"
fi

log "Initializing Terraform"
terraform -chdir="${TF_DIR}" init -upgrade=false

log "Applying Terraform (Apigee X, SA, Model Armor, Proxy, Data Collectors, Product, Developer, App, Custom Report)"
terraform -chdir="${TF_DIR}" apply -auto-approve

log "Deployment Summary"
echo "  Apigee Org:         $(terraform -chdir="${TF_DIR}" output -raw apigee_org)"
echo "  Environment:        $(terraform -chdir="${TF_DIR}" output -raw apigee_environment)"
echo "  Proxy SA:           $(terraform -chdir="${TF_DIR}" output -raw apigee_sa_email)"
echo "  Gateway URL:        $(terraform -chdir="${TF_DIR}" output -raw gateway_url)"
echo "  Custom Report:      $(terraform -chdir="${TF_DIR}" output -raw custom_report_display_name)"

if [ "${SKIP_VERIFY:-false}" != "true" ]; then
  log "Running verification suite"
  "${ROOT_DIR}/scripts/verify.sh" || warn "Some verification checks did not pass yet (e.g., Google-managed SSL cert may still be provisioning)."
fi
