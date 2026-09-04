# =============================================================================
# Makefile : コマンドのショートカット
#   ENV は dev / stg / prd（既定: dev）
#   例: make plan ENV=stg / make dataform-run TAGS=silver
# =============================================================================
SHELL   := /bin/bash
ENV     ?= dev
SYSTEM  ?= example
REGION  ?= asia-northeast1
PROJECT := $(SYSTEM)-$(ENV)
TAGS    ?= silver
DATAFORM_REMOTE ?=
DATAFORM_BRANCH ?= main

.DEFAULT_GOAL := help

.PHONY: help
help: ## このヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- セットアップ -------------------------------------------------------------
.PHONY: init
init: ## ローカル開発環境を初期化する
	scripts/init-local.sh

.PHONY: bootstrap
bootstrap: ## tfstateバケット等の初期GCPリソースを作る（環境ごとに1回）
	scripts/bootstrap-gcp.sh $(ENV)

.PHONY: login
login: ## gcloud の認証・プロジェクトを切り替える
	bin/gcp-login.sh $(ENV)

.PHONY: secrets
secrets: ## Secret Manager へ値を投入する（値はtfstateに残さない）
	@read -rsp "user API key: " V; echo; \
	 echo -n "$$V" | gcloud secrets versions add sec-user-api-key --data-file=- --project=$(PROJECT)
	@read -rsp "Slack webhook URL: " V; echo; \
	 echo -n "$$V" | gcloud secrets versions add sec-notification-webhook-url --data-file=- --project=$(PROJECT)
	@read -rsp "Dataform用GitHubトークン(read-only): " V; echo; \
	 echo -n "$$V" | gcloud secrets versions add sec-dataform-github-token --data-file=- --project=$(PROJECT)

# --- インフラ -----------------------------------------------------------------
.PHONY: plan
plan: ## terraform plan
	cd terraform && terraform init -reconfigure -backend-config="bucket=$(SYSTEM)-$(ENV)-tfstate" \
	 && terraform plan -var-file="environments/$(ENV).tfvars"

.PHONY: apply
apply: ## terraform apply（prd はCI/CD経由で行うこと）
	@if [ "$(ENV)" = "prd" ]; then echo "本番への apply はCI/CD（tf-apply.yml）から行ってください。"; exit 1; fi
	cd terraform && terraform init -reconfigure -backend-config="bucket=$(SYSTEM)-$(ENV)-tfstate" \
	 && terraform apply -var-file="environments/$(ENV).tfvars"

.PHONY: fmt
fmt: ## terraform fmt
	terraform fmt -recursive terraform/

# --- Dataform -----------------------------------------------------------------
.PHONY: dataform-compile
dataform-compile: ## Dataformのコンパイル検証（vars必須）
	bin/dataform-local.sh $(ENV) compile

.PHONY: dataform-dry-run
dataform-dry-run: ## Dataformのdry-run
	bin/dataform-local.sh $(ENV) run --dry-run

.PHONY: dataform-run
dataform-run: ## Dataformをローカルから実行（TAGS=silver）
	bin/dataform-local.sh $(ENV) run --tags $(TAGS)

.PHONY: dataform-push
dataform-push: ## dataform_project/ を別リポジトリへ反映（DATAFORM_REMOTE=... 必須）
	@if [ -z "$(DATAFORM_REMOTE)" ]; then echo "DATAFORM_REMOTE を指定してください"; exit 1; fi
	bin/dataform-push.sh $(DATAFORM_REMOTE) $(DATAFORM_BRANCH)

# --- 検証 ---------------------------------------------------------------------
.PHONY: test
test: ## Pythonの単体テスト
	pytest -v

.PHONY: lint
lint: ## Python / SQL / Terraform のLint
	ruff check app tests
	sqlfluff lint app/queries --dialect bigquery
	terraform fmt -check -recursive terraform/
	cd dataform_project && dataform compile --default-database $(PROJECT) --vars env:$(ENV),etl_ts:2026-01-01T00:00:00Z,batch_id:lint,window_months:14 >/dev/null

# --- 運用 ---------------------------------------------------------------------
.PHONY: run-pipeline
run-pipeline: ## 日次パイプラインを手動実行する
	gcloud workflows run wf-main-daily --location=$(REGION) --project=$(PROJECT)

.PHONY: logs
logs: ## 直近のパイプラインログを表示（RUN_ID=... で絞り込み）
	gcloud logging read 'resource.type="workflows.googleapis.com/Workflow"' \
	 --project=$(PROJECT) --limit=50 --format=json | jq -r '.[] | "\(.timestamp) \(.jsonPayload // .textPayload)"'
