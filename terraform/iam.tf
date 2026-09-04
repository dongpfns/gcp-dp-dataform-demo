# =============================================================================
# iam.tf : サービスアカウントとロール付与
# 規約: v2/30_iam_security.md
#   - 役割ごとにSAを分ける（リソースごとではない）
#   - 基本ロール（owner/editor/viewer）は付与しない
#   - SAキー（JSON）は発行しない
# =============================================================================

# -----------------------------------------------------------------------------
# サービスアカウント
# -----------------------------------------------------------------------------
resource "google_service_account" "ingest" {
  account_id   = "sa-ingest"
  display_name = "取込処理用SA"
  description  = "Cloud Functions / Cloud Run Jobs / DTS が使用。BRONZEへの書き込みとrawへのアップロードのみ"
}

resource "google_service_account" "transform" {
  account_id   = "sa-transform"
  display_name = "変換処理用SA"
  description  = "変換処理が使用（Dataformサービスエージェントと同じ境界）。BRONZE参照 + SILVER/GOLD編集。BRONZEへの書き込み権限は持たない"
}

resource "google_service_account" "workflow" {
  account_id   = "sa-workflow"
  display_name = "Workflows実行用SA"
  description  = "Workflowsが各コンポーネントを呼び出すために使用"
}

resource "google_service_account" "scheduler" {
  account_id   = "sa-scheduler"
  display_name = "Cloud Scheduler用SA"
  description  = "SchedulerがWorkflowsを起動するためだけに使用（workflows.invoker のみ）"
}

resource "google_service_account" "bi" {
  account_id   = "sa-bi"
  display_name = "BIツール接続用SA"
  description  = "BIツールがGOLD層を参照するために使用。SILVERへの権限は持たない"
}

# -----------------------------------------------------------------------------
# sa-ingest : raw への書き込み + BQジョブ実行
#   BRONZEデータセットへの編集権限は bigquery.tf のデータセットACLで付与している
# -----------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "ingest_raw" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingest.email}"
}

resource "google_storage_bucket_iam_member" "ingest_tmp" {
  bucket = google_storage_bucket.tmp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingest.email}"
}

resource "google_project_iam_member" "ingest_bq_job" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingest.email}"
}

# -----------------------------------------------------------------------------
# sa-transform : BQジョブ実行 + raw の参照（外部テーブル用）
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "transform_bq_job" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.transform.email}"
}

resource "google_storage_bucket_iam_member" "transform_raw_read" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.transform.email}"
}

resource "google_storage_bucket_iam_member" "transform_artifacts" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.transform.email}"
}

# -----------------------------------------------------------------------------
# sa-workflow : 各コンポーネントの呼び出し権限
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "workflow_roles" {
  for_each = toset([
    "roles/run.invoker",                     # Cloud Functions Gen2 / Cloud Run Jobs の呼び出し
    "roles/bigquery.jobUser",                # 品質チェックSQLの実行
    "roles/pubsub.publisher",                # 通知
    "roles/logging.logWriter",               # 構造化ログ
    "roles/workflows.invoker",               # サブワークフローの起動
    "roles/dataform.editor",                 # Dataformのコンパイル・実行
  ])

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

# Workflowsが他のSAとして振る舞うために必要
resource "google_service_account_iam_member" "workflow_act_as_ingest" {
  service_account_id = google_service_account.ingest.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_service_account_iam_member" "workflow_act_as_transform" {
  service_account_id = google_service_account.transform.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflow.email}"
}

# -----------------------------------------------------------------------------
# sa-scheduler : Workflowsの起動のみ
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "scheduler_workflows_invoker" {
  project = var.gcp_project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# -----------------------------------------------------------------------------
# sa-bi : GOLD参照 + BQジョブ実行
#   GOLDデータセットへの参照権限は bigquery.tf のデータセットACLで付与している
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "bi_bq_job" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.bi.email}"
}
