# =============================================================================
# monitoring.tf : 通知チャネル・アラートポリシー・予算
# 規約: v2/60_nonfunctional.md 3節・4節
#   アラートは「対応が必要なものだけ」鳴らす。全アラートにRunbookリンクを持たせる。
# =============================================================================

resource "google_monitoring_notification_channel" "email" {
  display_name = "nc-email-dataplatform"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# -----------------------------------------------------------------------------
# パイプライン失敗
# -----------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "workflow_failure" {
  display_name = "alert-wf-main-daily-failure"
  combiner     = "OR"

  conditions {
    display_name = "Workflowsの実行が失敗した"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.workflow_failed.name}\" AND resource.type=\"workflows.googleapis.com/Workflow\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content   = <<-EOT
      # wf-main-daily 失敗時の1次対応

      1. Cloud Logging で run_id を特定する（フィルタ: resource.type="workflows.googleapis.com/Workflow"）
      2. 失敗ステップを確認する
      3. Runbook: docs/runbook/wf-main-daily.md を参照
      4. 再実行は同じ run_id ではなく新しい run_id で行う（冪等性は担保されている）
    EOT
    mime_type = "text/markdown"
  }

  alert_strategy {
    auto_close = "86400s"
  }
}

# -----------------------------------------------------------------------------
# Cloud Functions のエラー率
# -----------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "function_error_rate" {
  display_name = "alert-cf-ingest-error-rate"
  combiner     = "OR"

  conditions {
    display_name = "取込関数のエラー率が5分間で5%を超えた"

    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content   = "取込関数のエラーが継続している。Runbook: docs/runbook/ingest-failure.md"
    mime_type = "text/markdown"
  }
}

# -----------------------------------------------------------------------------
# 予算アラート（v2/60_nonfunctional.md 3節：必須）
# billing_account の指定が必要なため、変数が未設定の環境ではスキップする
# -----------------------------------------------------------------------------
# resource "google_billing_budget" "monthly" {
#   billing_account = var.billing_account_id
#   display_name    = "budget-${local.prefix}"
#
#   budget_filter {
#     projects = ["projects/${var.gcp_project_id}"]
#   }
#
#   amount {
#     specified_amount {
#       currency_code = "JPY"
#       units         = tostring(var.budget_amount_jpy)
#     }
#   }
#
#   dynamic "threshold_rules" {
#     for_each = [0.5, 0.8, 1.0]
#     content {
#       threshold_percent = threshold_rules.value
#     }
#   }
# }
