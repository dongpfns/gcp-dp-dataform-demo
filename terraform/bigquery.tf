# =============================================================================
# bigquery.tf : データセットとテーブル
# 規約: v2/11_naming_bigquery.md / v2/40_infra_terraform.md
#       Terraform識別子は実リソース名と完全一致させる
# =============================================================================

# -----------------------------------------------------------------------------
# BRONZE : 連携元システム単位
# -----------------------------------------------------------------------------
module "ds_bronze_user_api" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_bronze_user_api
  description = "BRONZE層：外部ユーザーAPIから取得した生データ。加工しない。オーナー=data-platform-team"
  location    = var.bq_location
  layer       = "bronze"
  option_name = "user_api"

  writers = ["serviceAccount:${local.sa_ingest_email}"]
  readers = ["serviceAccount:${local.sa_transform_email}"]
}

module "ds_bronze_file_csv" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_bronze_file_csv
  description = "BRONZE層：CSVファイル連携の生データ。加工しない。オーナー=data-platform-team"
  location    = var.bq_location
  layer       = "bronze"
  option_name = "file_csv"

  writers = ["serviceAccount:${local.sa_ingest_email}"]
  readers = ["serviceAccount:${local.sa_transform_email}"]
}

# -----------------------------------------------------------------------------
# SILVER : 業務ドメイン単位
# -----------------------------------------------------------------------------
module "ds_silver_common" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_silver_common
  description = "SILVER層：全ドメイン共通のマスタ。標準化済み。オーナー=data-platform-team"
  location    = var.bq_location
  layer       = "silver"
  option_name = "common"

  writers = ["serviceAccount:${local.sa_transform_email}"]
}

module "ds_silver_sales" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_silver_sales
  description = "SILVER層：売上ドメイン。標準化済みのファクト。オーナー=data-platform-team"
  location    = var.bq_location
  layer       = "silver"
  option_name = "sales"

  writers = ["serviceAccount:${local.sa_transform_email}"]
}

# -----------------------------------------------------------------------------
# GOLD : 利用者単位（このデータセットがそのままIAM境界になる）
# -----------------------------------------------------------------------------
module "ds_gold_bi_tool" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_gold_bi_tool
  description = "GOLD層：BIツール向けデータマート。派生指標はここでのみ生成する"
  location    = var.bq_location
  layer       = "gold"
  option_name = "bi_tool"

  writers = ["serviceAccount:${local.sa_transform_email}"]
  readers = ["serviceAccount:${google_service_account.bi.email}"]
}

# -----------------------------------------------------------------------------
# 運用
# -----------------------------------------------------------------------------
module "ds_ops_dataquality" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_ops_dataquality
  description = "運用：データ品質チェック結果の蓄積先（v2/60_nonfunctional.md 6節）"
  location    = var.bq_location
  layer       = "ops"
  option_name = "dataquality"

  writers = [
    "serviceAccount:${local.sa_transform_email}",
    "serviceAccount:${local.sa_workflow_email}",
  ]
}

module "ds_ops_audit" {
  source      = "./modules/bigquery_dataset"
  dataset_id  = local.ds_ops_audit
  description = "運用：ジョブ実行履歴・監査ログの保管先"
  location    = var.bq_location
  layer       = "ops"
  option_name = "audit"

  writers = ["serviceAccount:${local.sa_workflow_email}"]
}

# =============================================================================
# テーブル（共通モジュール経由）
# =============================================================================

# ディメンション：クラスタ必須・パーティションなし
module "d_account" {
  source      = "./modules/bigquery_table"
  dataset_id  = module.ds_silver_common.dataset_id
  table_id    = "d_account"
  description = "ユーザーマスタ（外部ユーザーAPI由来）。P1 全件洗替 + 物理削除検知"
  schema_file = "${path.module}/schemas/silver_common/d_account.json"
  layer       = "silver"
  option_name = "common"

  clustering          = ["account_id"]
  deletion_protection = var.enable_deletion_protection
}

# ファクト：パーティション必須。MONTH粒度なので基準日列を第1クラスタ列に置く
module "f_30m_sales_transaction" {
  source      = "./modules/bigquery_table"
  dataset_id  = module.ds_silver_sales.dataset_id
  table_id    = "f_30m_sales_transaction"
  description = "売上トランザクション（30分粒度）。P2 範囲洗替（月境界・14か月ウィンドウ）"
  schema_file = "${path.module}/schemas/silver_sales/f_30m_sales_transaction.json"
  layer       = "silver"
  option_name = "sales"

  partition_field          = "business_date"
  partition_granularity    = var.fact_partition_granularity
  require_partition_filter = true
  clustering               = ["business_date", "store_cd", "account_id"]
  deletion_protection      = var.enable_deletion_protection
}

# 品質チェック結果（v2/60_nonfunctional.md 6節）
resource "google_bigquery_table" "check_result" {
  dataset_id          = module.ds_ops_dataquality.dataset_id
  table_id            = "check_result"
  description         = "データ品質チェックの実行結果"
  deletion_protection = false

  time_partitioning {
    type                     = "MONTH"
    field                    = "checked_at_utc"
    require_partition_filter = false
  }

  schema = jsonencode([
    { name = "run_id", type = "STRING", mode = "REQUIRED", description = "パイプライン実行ID" },
    { name = "check_name", type = "STRING", mode = "REQUIRED", description = "チェック名" },
    { name = "target_table", type = "STRING", mode = "REQUIRED", description = "対象テーブル（dataset.table）" },
    { name = "status", type = "STRING", mode = "REQUIRED", description = "PASS / WARN / FAIL" },
    { name = "actual_value", type = "NUMERIC", mode = "NULLABLE", description = "実測値" },
    { name = "threshold_value", type = "NUMERIC", mode = "NULLABLE", description = "閾値" },
    { name = "message", type = "STRING", mode = "NULLABLE", description = "補足メッセージ" },
    { name = "checked_at_utc", type = "TIMESTAMP", mode = "REQUIRED", description = "チェック実行日時（UTC）" },
  ])

  labels = { layer = "ops", option_name = "dataquality" }
}

# ジョブ実行履歴（二重起動防止・実行監査に使う）
resource "google_bigquery_table" "job_run" {
  dataset_id          = module.ds_ops_audit.dataset_id
  table_id            = "job_run"
  description         = "パイプライン実行履歴。二重起動防止と実行監査に使用"
  deletion_protection = false

  time_partitioning {
    type                     = "MONTH"
    field                    = "started_at_utc"
    require_partition_filter = false
  }

  schema = jsonencode([
    { name = "run_id", type = "STRING", mode = "REQUIRED", description = "パイプライン実行ID" },
    { name = "workflow_name", type = "STRING", mode = "REQUIRED", description = "Workflow名" },
    { name = "status", type = "STRING", mode = "REQUIRED", description = "RUNNING / SUCCEEDED / FAILED / SKIPPED" },
    { name = "step_name", type = "STRING", mode = "NULLABLE", description = "失敗したステップ名" },
    { name = "error_message", type = "STRING", mode = "NULLABLE", description = "エラー内容" },
    { name = "started_at_utc", type = "TIMESTAMP", mode = "REQUIRED", description = "開始日時（UTC）" },
    { name = "finished_at_utc", type = "TIMESTAMP", mode = "NULLABLE", description = "終了日時（UTC）" },
  ])

  labels = { layer = "ops", option_name = "audit" }
}
