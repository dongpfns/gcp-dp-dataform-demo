#!/usr/bin/env bash
# =============================================================================
# dataform-local.sh : ローカルでDataform CLIを実行する
#   vars を必ず渡すのがポイント。渡さないと includes/audit_columns.js が
#   undefined を埋め込み、監査列が壊れたSQLが生成される。
#
# 使い方:
#   bin/dataform-local.sh dev compile
#   bin/dataform-local.sh dev run --dry-run
#   bin/dataform-local.sh dev run --tags silver --full-refresh
# =============================================================================
set -euo pipefail

ENV="${1:?環境コードを指定してください (dev / stg / prd)}"
shift

SYSTEM="${SYSTEM:-example}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${SYSTEM}-${ENV}"
WINDOW_MONTHS="${WINDOW_MONTHS:-14}"

ETL_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BATCH_ID="local-$(date -u +%Y%m%dT%H%M%SZ)"

if ! command -v dataform >/dev/null 2>&1; then
  echo "dataform CLI がありません: npm install -g @dataform/cli@3.0.2" >&2
  exit 1
fi

cd "${ROOT}/dataform_project"
[[ -d node_modules ]] || dataform install

echo "==> dataform $* (project=${PROJECT_ID}, env=${ENV})"
dataform "$@" \
  --default-database "${PROJECT_ID}" \
  --vars "env:${ENV},etl_ts:${ETL_TS},batch_id:${BATCH_ID},window_months:${WINDOW_MONTHS}"
