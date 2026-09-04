# =============================================================================
# run_jobs.tf : Cloud Run Jobs
# 規約: v2/12_naming_gcp_resources.md 4節 / v2/22_orchestration.md 4節
#   本構成の変換はDataformが担うため、Cloud Run Jobs は取込のみ。
#   - フォルダ app/run-jobs/{name}/ ↔ ジョブ名 crj-{name}
#   - イメージタグは必ずGitコミットSHA（latest 禁止）
#   - max_retries = 0（リトライはWorkflows側で制御。二重に効くと制御不能になる）
# =============================================================================

resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "ar-images"
  description   = "Cloud Run Jobs のコンテナイメージ"
  format        = "DOCKER"

  labels = { layer = "common" }

  depends_on = [google_project_service.this]
}

resource "google_artifact_registry_repository_iam_member" "ingest_reader" {
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.ingest.email}"
}

locals {
  image_base = "${var.region}-docker.pkg.dev/${var.gcp_project_id}/ar-images"
}

# -----------------------------------------------------------------------------
# user-sync-job : 外部APIからユーザーデータを取得する（app/run-jobs/user-sync-job/）
# -----------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "user_sync" {
  name     = "crj-user-sync"
  location = var.region

  template {
    task_count = 1

    template {
      service_account = google_service_account.ingest.email
      timeout         = "1800s"
      max_retries     = 0

      containers {
        image = "${local.image_base}/user-sync-job:${var.user_sync_image_tag}"

        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.gcp_project_id
        }
        env {
          name  = "ENV"
          value = var.env
        }
        env {
          name  = "RAW_BUCKET"
          value = google_storage_bucket.raw.name
        }
        env {
          name  = "API_BASE_URL"
          value = var.user_api_base_url
        }
        # ETL_BATCH_ID / ETL_TS は Workflows が overrides で注入する
      }
    }
  }

  labels = { layer = "bronze" }

  lifecycle {
    # イメージタグはCI（run-job-user-sync.yml）が更新するため、
    # tf-apply 側の差分では上書きしない
    ignore_changes = [template[0].template[0].containers[0].image]
  }
}

# Workflowsからの起動を許可
resource "google_cloud_run_v2_job_iam_member" "user_sync_invoker" {
  location = var.region
  name     = google_cloud_run_v2_job.user_sync.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.workflow.email}"
}

