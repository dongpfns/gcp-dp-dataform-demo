# =============================================================================
# workflows.tf : オーケストレーション
# 規約: v2/22_orchestration.md
#   - 定義ファイル名はワークフロー名と完全一致させる（app/workflows/wf-main-daily.yaml）
#   - Workflowsが唯一の司令塔
#   - Dataformは compilationResults.create → workflowInvocations.create の2段で起動する
# =============================================================================

resource "google_workflows_workflow" "main_daily" {
  name            = "wf-main-daily"
  region          = var.region
  description     = "日次パイプライン：取込(Job) → BRONZE品質チェック → Dataform実行 → 品質チェック → 通知"
  service_account = google_service_account.workflow.id

  source_contents = templatefile("${path.module}/../app/workflows/wf-main-daily.yaml", {
    gcp_project_id    = var.gcp_project_id
    region            = var.region
    env               = var.env
    job_user_sync     = google_cloud_run_v2_job.user_sync.name
    dataform_repo     = google_dataform_repository.main.name
    dataform_release  = google_dataform_repository_release_config.env.name
    topic_failed      = google_pubsub_topic.pipeline_failed.name
    ops_audit_dataset = module.ds_ops_audit.dataset_id
    ops_dq_dataset    = module.ds_ops_dataquality.dataset_id
  })

  labels = { layer = "common" }

  depends_on = [google_project_service.this]
}
