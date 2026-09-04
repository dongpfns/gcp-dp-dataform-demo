# =============================================================================
# scheduler.tf : 定時起動
# 規約: v2/22_orchestration.md
#   - SchedulerはWorkflowsしか起動しない
#   - タイムゾーンは Asia/Tokyo に統一
#   - リトライは0回（リトライはWorkflows側で制御し、二重起動を防ぐ）
# =============================================================================

resource "google_cloud_scheduler_job" "wf_main_daily" {
  name        = "sch-wf-main-daily"
  region      = var.region
  description = "日次パイプラインの起動（JST ${var.schedule_daily_cron}）"
  schedule    = var.schedule_daily_cron
  time_zone   = "Asia/Tokyo"

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.main_daily.id}/executions"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }

  depends_on = [google_project_service.this]
}
