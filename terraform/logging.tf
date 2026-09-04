# =============================================================================
# logging.tf : ログシンク・ログベース指標
# 規約: v2/60_nonfunctional.md 5節
# =============================================================================

# BigQueryのデータアクセス監査ログを ops_audit へ保管する
resource "google_logging_project_sink" "bq_audit" {
  name        = "sink-bq-audit"
  destination = "bigquery.googleapis.com/projects/${var.gcp_project_id}/datasets/${module.ds_ops_audit.dataset_id}"

  filter = <<-EOT
    protoPayload.serviceName="bigquery.googleapis.com"
    AND (protoPayload.methodName="jobservice.jobcompleted"
         OR protoPayload.methodName="google.cloud.bigquery.v2.JobService.InsertJob")
  EOT

  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "sink_writer" {
  dataset_id = module.ds_ops_audit.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.bq_audit.writer_identity
}

# Workflowsの失敗を検知するログベース指標
resource "google_logging_metric" "workflow_failed" {
  name        = "workflow_execution_failed"
  description = "Workflowsの実行失敗回数"

  filter = <<-EOT
    resource.type="workflows.googleapis.com/Workflow"
    AND severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"

    labels {
      key         = "workflow_name"
      value_type  = "STRING"
      description = "ワークフロー名"
    }
  }

  label_extractors = {
    "workflow_name" = "EXTRACT(resource.labels.workflow_id)"
  }
}
