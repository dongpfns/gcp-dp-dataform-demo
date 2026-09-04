# =============================================================================
# locals.tf : 命名の組み立てを集約する
# 規約: 各 .tf でリソース名の文字列を組み立てない（v2/40_infra_terraform.md 3節）
# =============================================================================

locals {
  # example-prd
  prefix = "${var.system}-${var.env}"

  # 全リソース共通ラベル（v2/12_naming_gcp_resources.md 6節）
  common_labels = {
    system     = var.system
    env        = var.env
    owner      = var.owner
    managed_by = "terraform"
  }

  # ---------------------------------------------------------------------------
  # GCSバケット（v2/13_naming_storage.md）
  # ---------------------------------------------------------------------------
  bucket_raw       = "${local.prefix}-raw"
  bucket_functions_src = "${local.prefix}-functions-src"
  bucket_artifacts     = "${local.prefix}-artifacts"
  bucket_tmp           = "${local.prefix}-tmp"
  bucket_export        = "${local.prefix}-export"

  # ---------------------------------------------------------------------------
  # BigQueryデータセット（v2/11_naming_bigquery.md 1節）
  # 環境コードは含めない。環境はGCPプロジェクトで分離済み。
  # ---------------------------------------------------------------------------
  ds_bronze_user_api   = "bronze_user_api"
  ds_bronze_file_csv   = "bronze_file_csv"
  ds_silver_common     = "silver_common"
  ds_silver_sales      = "silver_sales"
  ds_gold_bi_tool      = "gold_bi_tool"
  ds_ops_dataquality   = "ops_dataquality"
  ds_ops_audit         = "ops_audit"

  # ---------------------------------------------------------------------------
  # サービスアカウント（v2/30_iam_security.md 2節）
  # ---------------------------------------------------------------------------
  sa_ingest_email    = google_service_account.ingest.email
  sa_transform_email = google_service_account.transform.email
  sa_workflow_email  = google_service_account.workflow.email
  sa_scheduler_email = google_service_account.scheduler.email
}
