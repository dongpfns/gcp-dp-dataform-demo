# =============================================================================
# outputs.tf : 運用・他システムから参照する値
# =============================================================================

output "gcp_project_id" {
  description = "GCPプロジェクトID"
  value       = var.gcp_project_id
}

output "bucket_raw" {
  description = "取込ファイルの着地バケット"
  value       = google_storage_bucket.raw.name
}

output "datasets" {
  description = "作成したBigQueryデータセットID"
  value = {
    bronze_user_api   = module.ds_bronze_user_api.dataset_id
    bronze_file_csv   = module.ds_bronze_file_csv.dataset_id
    silver_common     = module.ds_silver_common.dataset_id
    silver_sales      = module.ds_silver_sales.dataset_id
    gold_bi_tool      = module.ds_gold_bi_tool.dataset_id
    ops_dataquality   = module.ds_ops_dataquality.dataset_id
  }
}

output "service_accounts" {
  description = "サービスアカウントのメールアドレス"
  value = {
    ingest    = google_service_account.ingest.email
    transform = google_service_account.transform.email
    workflow  = google_service_account.workflow.email
    scheduler = google_service_account.scheduler.email
  }
}

output "dataform" {
  description = "Dataformリポジトリと参照ブランチ"
  value = {
    repository     = google_dataform_repository.main.name
    branch         = var.dataform_git_branch
    release_config = google_dataform_repository_release_config.env.name
  }
}

output "workflow_main_daily" {
  description = "日次パイプラインのWorkflow名"
  value       = google_workflows_workflow.main_daily.name
}

output "run_jobs" {
  description = "Cloud Run Jobs 名"
  value = {
    user_sync = google_cloud_run_v2_job.user_sync.name
  }
}

output "functions" {
  description = "Cloud Functions 名"
  value = {
    gcs_csv_trigger = google_cloudfunctions2_function.gcs_csv_trigger.name
    slack_notifier  = google_cloudfunctions2_function.slack_notifier.name
  }
}
