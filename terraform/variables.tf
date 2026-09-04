# =============================================================================
# variables.tf : 変数宣言
# 規約: 全変数に type と description。環境依存の値に default を置かない。
#       取りうる値が決まっている変数は validation で制限する。
# =============================================================================

variable "system" {
  type        = string
  description = "システム識別子。GCPプロジェクトID・バケット名の接頭辞になる（例: example）"
}

variable "env" {
  type        = string
  description = "環境コード（dev / stg / prd）"

  validation {
    condition     = contains(["dev", "stg", "prd"], var.env)
    error_message = "env は dev / stg / prd のいずれかを指定してください。"
  }
}

variable "gcp_project_id" {
  type        = string
  description = "GCPプロジェクトID（例: example-prd）"
}

variable "region" {
  type        = string
  description = "リソースを作成するリージョン"
  default     = "asia-northeast1"
}

variable "bq_location" {
  type        = string
  description = "BigQuery / GCS のロケーション。跨ぐとJOIN不可・追加コストが発生するため統一する"
  default     = "asia-northeast1"
}

variable "owner" {
  type        = string
  description = "オーナーチーム名（ラベル owner の値。小文字英数字とハイフンのみ）"
  default     = "data-platform-team"
}

# -----------------------------------------------------------------------------
# 変換基盤（Dataform）
# 規約: v2/21_transform.md 5節 / v2/50_git_cicd.md 6節
#   Dataformに「デプロイ」工程は存在しない。指定したGitHubリポジトリの
#   指定ブランチを、Dataformがその場でコンパイルして実行する。
# -----------------------------------------------------------------------------
variable "dataform_github_owner" {
  type        = string
  description = "DataformリポジトリのGitHub Organization / ユーザー名"
}

variable "dataform_repo_name" {
  type        = string
  description = "DataformのGitHubリポジトリ名（dataform_project/ を切り出した先）"
  default     = "example-dataform"
}

variable "dataform_git_branch" {
  type        = string
  description = "この環境が参照するGitブランチ（prd=main / stg=staging / dev=develop）"
}

# -----------------------------------------------------------------------------
# Cloud Run Jobs のイメージタグ
# 規約: 必ずGitコミットSHAを指定する（latest 禁止 / v2/12_naming_gcp_resources.md 4節）
#       通常はCI（run-job-*.yml）が更新するため、tfvars の値はブートストラップ用。
# -----------------------------------------------------------------------------
variable "user_sync_image_tag" {
  type        = string
  description = "crj-user-sync のイメージタグ（GitコミットSHA）"
  default     = "bootstrap"
}

variable "user_api_base_url" {
  type        = string
  description = "user-sync-job が参照する外部APIのベースURL"
  default     = "https://api.example.com/v1"
}

# -----------------------------------------------------------------------------
# BigQuery
# -----------------------------------------------------------------------------
variable "fact_partition_granularity" {
  type        = string
  description = "ファクトテーブルのパーティション粒度。10年以上保持するテーブルは MONTH（v2/11_naming_bigquery.md 3.1）"
  default     = "MONTH"

  validation {
    condition     = contains(["DAY", "MONTH", "YEAR"], var.fact_partition_granularity)
    error_message = "fact_partition_granularity は DAY / MONTH / YEAR のいずれかを指定してください。"
  }
}

variable "enable_deletion_protection" {
  type        = bool
  description = "BigQueryテーブルの削除保護。本番は true"
}

# -----------------------------------------------------------------------------
# スケジュール・通知
# -----------------------------------------------------------------------------
variable "schedule_daily_cron" {
  type        = string
  description = "日次パイプラインの起動時刻（cron式・Asia/Tokyo）"
  default     = "0 5 * * *"
}

variable "notification_email" {
  type        = string
  description = "アラート通知先メールアドレス"
  default     = "data-platform@example.com"
}

variable "budget_amount_jpy" {
  type        = number
  description = "月次予算（円）。予算アラートの基準額"
  default     = 100000
}
