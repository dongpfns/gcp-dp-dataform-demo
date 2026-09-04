# =============================================================================
# functions.tf : Cloud Functions (Gen2 / Python 3.12)
# 規約: v2/12_naming_gcp_resources.md 2節 / v2/22_orchestration.md 3節
#   - フォルダ app/functions/{name}/ ↔ 関数名 cf-{name}
#   - エントリポイントは main に統一
#   - 1関数 = 1責務
# =============================================================================

locals {
  functions = {
    "gcs-csv-trigger" = {
      description = "GCS raw にCSVが置かれたらBRONZEへロードする（Eventarc / GCS）"
      timeout_s   = 540
      memory      = "512Mi"
      env = {
        CSV_ENCODING  = "UTF-8"
        CSV_SKIP_ROWS = "1"
      }
    }
    "slack-notifier" = {
      description = "パイプラインの失敗をSlackへ通知する（Pub/Sub）"
      timeout_s   = 60
      memory      = "256Mi"
      env = {
        WEBHOOK_SECRET_ID = "sec-notification-webhook-url"
      }
    }
  }
}

# ソースZIP。data.archive_file は各関数ディレクトリをそのまま固める
# （Functionsは自己完結の実装にしてあり、共有ライブラリに依存しない）。
data "archive_file" "function_src" {
  for_each = local.functions

  type        = "zip"
  source_dir  = "${path.module}/../app/functions/${each.key}"
  output_path = "${path.module}/.build/${each.key}.zip"
}

# ZIPのハッシュをオブジェクト名に含め、コード変更をTerraformに検知させる
resource "google_storage_bucket_object" "function_src" {
  for_each = local.functions

  name   = "functions/${each.key}/${data.archive_file.function_src[each.key].output_md5}.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.function_src[each.key].output_path
}

# -----------------------------------------------------------------------------
# ① cf-gcs-csv-trigger : GCS オブジェクト作成で起動
# -----------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "gcs_csv_trigger" {
  name        = "cf-gcs-csv-trigger"
  location    = var.region
  description = local.functions["gcs-csv-trigger"].description

  build_config {
    runtime     = "python312"
    entry_point = "main"

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.function_src["gcs-csv-trigger"].name
      }
    }
  }

  service_config {
    available_memory      = local.functions["gcs-csv-trigger"].memory
    timeout_seconds       = local.functions["gcs-csv-trigger"].timeout_s
    min_instance_count    = 0
    max_instance_count    = 10
    service_account_email = google_service_account.ingest.email
    ingress_settings      = "ALLOW_INTERNAL_ONLY"

    environment_variables = merge(
      {
        GCP_PROJECT_ID = var.gcp_project_id
        ENV            = var.env
      },
      local.functions["gcs-csv-trigger"].env,
    )
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.ingest.email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.raw.name
    }
  }

  labels = { layer = "bronze" }

  depends_on = [google_project_service.this]
}

# -----------------------------------------------------------------------------
# ② cf-slack-notifier : Pub/Sub（失敗通知トピック）で起動
# -----------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "slack_notifier" {
  name        = "cf-slack-notifier"
  location    = var.region
  description = local.functions["slack-notifier"].description

  build_config {
    runtime     = "python312"
    entry_point = "main"

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.function_src["slack-notifier"].name
      }
    }
  }

  service_config {
    available_memory      = local.functions["slack-notifier"].memory
    timeout_seconds       = local.functions["slack-notifier"].timeout_s
    min_instance_count    = 0
    max_instance_count    = 3
    service_account_email = google_service_account.workflow.email
    ingress_settings      = "ALLOW_INTERNAL_ONLY"

    environment_variables = merge(
      {
        GCP_PROJECT_ID = var.gcp_project_id
        ENV            = var.env
      },
      local.functions["slack-notifier"].env,
    )
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.pipeline_failed.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.workflow.email
  }

  labels = { layer = "common" }

  depends_on = [google_project_service.this]
}
