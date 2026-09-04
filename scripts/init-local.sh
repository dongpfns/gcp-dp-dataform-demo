#!/usr/bin/env bash
# =============================================================================
# init-local.sh : ローカル開発環境の初期設定
#   必要なツールの有無を確認し、Python仮想環境を用意する。
#
# 使い方: scripts/init-local.sh
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '  [OK]   %-10s %s\n' "$1" "$($2 2>&1 | head -1)"
  else
    printf '  [MISS] %-10s %s\n' "$1" "$3"
    MISSING=1
  fi
}

MISSING=0
echo "==> 必要なツールの確認"
check gcloud    "gcloud version"       "https://cloud.google.com/sdk/docs/install"
check terraform "terraform version"    "https://developer.hashicorp.com/terraform/install"
check docker    "docker --version"     "https://docs.docker.com/get-docker/"
check python3   "python3 --version"    "Python 3.12 以上をインストールしてください"
check jq        "jq --version"         "brew install jq / apt-get install jq"

if [[ "${MISSING}" == "1" ]]; then
  echo
  echo "不足しているツールをインストールしてから再実行してください。"
  exit 1
fi

echo
echo "==> Python仮想環境を作成 (.venv)"
python3 -m venv "${ROOT}/.venv"
# shellcheck disable=SC1091
source "${ROOT}/.venv/bin/activate"
pip install --upgrade pip --quiet
pip install -r "${ROOT}/requirements-dev.txt" --quiet

echo
echo "==> 完了。次の手順:"
echo "  1. source .venv/bin/activate"
echo "  2. bin/gcp-login.sh dev"
echo "  3. make test"
