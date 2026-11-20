#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

if [ -z "${GOOGLE_OAUTH_ACCESS_TOKEN:-}" ] && [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  CLI_ACCT="$(gcloud config get-value account 2>/dev/null || true)"
  ADC_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
  ADC_ACCT=""
  if [ -n "$ADC_TOKEN" ]; then
    ADC_ACCT="$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=${ADC_TOKEN}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('email',''))" 2>/dev/null || true)"
  fi
  if [ -n "$CLI_ACCT" ] && [ "$CLI_ACCT" != "$ADC_ACCT" ]; then
    export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
  fi
fi

echo "==> Destroying Apigee AI Gateway Quickstart resources..."
terraform -chdir="${TF_DIR}" destroy -auto-approve
