# =============================================================================
# pubsub.tf : 通知・イベント連携
# 規約: v2/12_naming_gcp_resources.md（ps- / sub- 接頭辞）
# =============================================================================

resource "google_pubsub_topic" "pipeline_failed" {
  name   = "ps-pipeline-failed"
  labels = { layer = "common" }
}

resource "google_pubsub_topic" "ingest_completed" {
  name   = "ps-ingest-completed"
  labels = { layer = "bronze" }
}

# 失敗通知をアラート経路へ流すためのサブスクリプション
resource "google_pubsub_subscription" "pipeline_failed_alert" {
  name  = "sub-ps-pipeline-failed-alert"
  topic = google_pubsub_topic.pipeline_failed.id

  ack_deadline_seconds       = 30
  message_retention_duration = "604800s" # 7日

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = { layer = "common" }
}
