#!/usr/bin/env bash
# =============================================================================
# gcp-login.sh : ローカルの認証・プロジェクトを手軽に切り替える
#   SAキーJSONは使わない（v2/30_iam_security.md 1節）。ADCでログインする。
#
# 使い方:
#   bin/gcp-login.sh dev
#   bin/gcp-login.sh prd
# =============================================================================
set -euo pipefail

ENV="${1:?環境コードを指定してください (dev / stg / prd)}"
SYSTEM="${SYSTEM:-example}"
PROJECT_ID="${SYSTEM}-${ENV}"

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "==> ADC が未設定のためログインします"
  gcloud auth application-default login
fi

gcloud config set project "${PROJECT_ID}"
gcloud auth application-default set-quota-project "${PROJECT_ID}"

echo "==> 現在の設定"
gcloud config list
echo
echo "アカウント: $(gcloud config get-value account)"
echo "プロジェクト: ${PROJECT_ID}"

if [[ "${ENV}" == "prd" ]]; then
  echo
  echo "⚠️  本番プロジェクトに切り替えました。書き込み操作は行わないでください。"
  echo "    本番への変更はすべてCI/CD経由です（v2/50_git_cicd.md 5節）。"
fi
