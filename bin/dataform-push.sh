#!/usr/bin/env bash
# =============================================================================
# dataform-push.sh : dataform_project/ だけを別リポジトリへ反映する
#
#   Dataformは git_remote_settings で指定したリポジトリを「そのまま」コンパイルし、
#   サブディレクトリ指定ができない。よって dataform_project/ は
#   {owner}/{repo} として単独のリポジトリに存在している必要がある。
#   本デモではレビューのしやすさを優先して同居させ、subtree で同期する。
#
# 使い方:
#   bin/dataform-push.sh git@github.com:your-org/example-dataform.git main
# =============================================================================
set -euo pipefail

REMOTE_URL="${1:?DataformリポジトリのURLを指定してください}"
BRANCH="${2:-main}"
REMOTE_NAME="dataform-origin"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! git remote get-url "${REMOTE_NAME}" >/dev/null 2>&1; then
  git remote add "${REMOTE_NAME}" "${REMOTE_URL}"
else
  git remote set-url "${REMOTE_NAME}" "${REMOTE_URL}"
fi

echo "==> dataform_project/ を ${REMOTE_URL} (${BRANCH}) へ反映"
git subtree push --prefix=dataform_project "${REMOTE_NAME}" "${BRANCH}"

cat <<'MSG'

==> 完了。反映後の確認:
  - Dataform は次回のコンパイルからこの内容を使う（デプロイ工程は存在しない）
  - Release Config（rc-{env}）が参照するブランチと一致しているか確認すること
MSG
