#!/usr/bin/env bash
# One-time GCP bootstrap for Story Line: project, billing, APIs, Terraform
# state bucket, Resend secrets and Firebase. Safe to re-run.
#
# Usage: PROJECT_ID=story-line-nra RESEND_API_KEY=… RESEND_FROM='Story Line <no-reply@…>' infra/gcp/bootstrap.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-story-line-nra}"
REGION="us-central1"
BILLING_ACCOUNT="01EDE2-969598-73D6AD"
STATE_BUCKET="gs://${PROJECT_ID}-tfstate"

secret_exists() {
  gcloud secrets describe "$1" --project "$PROJECT_ID" >/dev/null 2>&1
}

# Fail before touching anything if a Resend secret is missing and has no value
# to create it from (a missing project or disabled API also reads as missing).
missing=()
secret_exists story-line-resend-api-key || [ -n "${RESEND_API_KEY:-}" ] || missing+=(RESEND_API_KEY)
secret_exists story-line-resend-from || [ -n "${RESEND_FROM:-}" ] || missing+=(RESEND_FROM)
if [ "${#missing[@]}" -gt 0 ]; then
  echo "error: ${missing[*]} must be set (the matching Secret Manager secret does not exist yet)." >&2
  echo "usage: RESEND_API_KEY=… RESEND_FROM='Story Line <no-reply@your-domain>' just gcp-bootstrap" >&2
  exit 1
fi

echo "==> Project $PROJECT_ID"
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud projects create "$PROJECT_ID" --name="Story Line"
fi

echo "==> Billing"
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT" >/dev/null

echo "==> APIs"
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  firebase.googleapis.com \
  firebasehosting.googleapis.com \
  storage.googleapis.com \
  --project "$PROJECT_ID"

echo "==> Terraform state bucket $STATE_BUCKET"
if ! gcloud storage buckets describe "$STATE_BUCKET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "$STATE_BUCKET" --project "$PROJECT_ID" \
    --location="$REGION" --uniform-bucket-level-access
fi
gcloud storage buckets update "$STATE_BUCKET" --project "$PROJECT_ID" --versioning >/dev/null

echo "==> Resend secrets"
create_secret() {
  local id="$1" value="$2"
  if secret_exists "$id"; then
    echo "$id exists; leaving it alone."
    return
  fi
  gcloud secrets create "$id" --project "$PROJECT_ID" --replication-policy=automatic
  printf %s "$value" | gcloud secrets versions add "$id" --project "$PROJECT_ID" --data-file=-
}
create_secret story-line-resend-api-key "${RESEND_API_KEY:-}"
create_secret story-line-resend-from "${RESEND_FROM:-}"

echo "==> Firebase"
# `firebase projects:list` lags behind addfirebase, so ask the Firebase API directly.
firebase_status=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: $PROJECT_ID" \
  "https://firebase.googleapis.com/v1beta1/projects/$PROJECT_ID")
if [ "$firebase_status" = 200 ]; then
  echo "Firebase already added to $PROJECT_ID."
else
  firebase projects:addfirebase "$PROJECT_ID"
fi

echo "==> Project number"
gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)'
