#!/usr/bin/env bash
# =============================================================================
# bootstrap-gcp.sh : Terraformを動かすための「最初のGCPリソース」を作る
#   - Terraformが動く最小限のAPI有効化
#   - tfstate用GCSバケット（Terraform管理外。鶏卵問題を避けるため）
#
# 使い方: scripts/bootstrap-gcp.sh dev
# =============================================================================
set -euo pipefail

ENV="${1:?環境コードを指定してください (dev / stg / prd)}"
SYSTEM="${SYSTEM:-example}"
REGION="${REGION:-asia-northeast1}"
PROJECT_ID="${SYSTEM}-${ENV}"
STATE_BUCKET="${SYSTEM}-${ENV}-tfstate"

echo "==> project: ${PROJECT_ID} / region: ${REGION}"
gcloud config set project "${PROJECT_ID}"

echo "==> Terraformが動くための最小限のAPIを有効化"
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com \
  --project="${PROJECT_ID}"

echo "==> tfstate用バケットを作成（バージョニング必須）"
if gcloud storage buckets describe "gs://${STATE_BUCKET}" >/dev/null 2>&1; then
  echo "    既に存在します: gs://${STATE_BUCKET}"
else
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi
gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning

cat <<'MSG'

==> 完了。次の手順:
  1. Secret Manager へ値を投入する（Terraform管理外 / v2/30_iam_security.md 5節）
       make secrets ENV=dev
  2. make plan ENV=dev
  3. make apply ENV=dev
MSG
