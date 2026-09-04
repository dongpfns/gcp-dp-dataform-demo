# =============================================================================
# dataform.tf : 変換基盤（Dataform）★本構成の中核
# 規約: v2/21_transform.md 5節 / v2/50_git_cicd.md 6節
#
# Dataformに「デプロイ」工程は存在しない。
# 指定したGitHubリポジトリの指定ブランチを、Dataformがその場でコンパイルして実行する。
# GitHub Actions の役割はデプロイではなく「検証（コンパイル + dry-run）」。
# =============================================================================

# -----------------------------------------------------------------------------
# サービスエージェント
#   ★最も詰まりやすい箇所★
#   API有効化直後はサービスエージェントが存在しないことがあり、
#   IAM付与が「そんなプリンシパルはいない」と失敗する。明示的に作成しておく。
# -----------------------------------------------------------------------------
resource "google_project_service_identity" "dataform" {
  provider = google-beta
  project  = var.gcp_project_id
  service  = "dataform.googleapis.com"

  depends_on = [google_project_service.this]
}

# GitHubトークンの読み取り権限（シークレット単位で付与する）
resource "google_secret_manager_secret_iam_member" "dataform_token" {
  secret_id = google_secret_manager_secret.this["sec-dataform-github-token"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_project_service_identity.dataform.email}"
}

# BigQueryジョブの実行権限
resource "google_project_iam_member" "dataform_bq_job" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_project_service_identity.dataform.email}"
}

# データセットへの権限は sa-transform と同じ境界にする。
# BRONZEは参照のみ、SILVER/GOLDは編集（bigquery.tf のデータセットACLで付与）。
resource "google_bigquery_dataset_iam_member" "dataform_bronze_reader" {
  for_each = toset([
    module.ds_bronze_user_api.dataset_id,
    module.ds_bronze_file_csv.dataset_id,
  ])

  dataset_id = each.value
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_project_service_identity.dataform.email}"
}

resource "google_bigquery_dataset_iam_member" "dataform_writer" {
  for_each = toset([
    module.ds_silver_common.dataset_id,
    module.ds_silver_sales.dataset_id,
    module.ds_gold_bi_tool.dataset_id,
    module.ds_ops_dataquality.dataset_id,
  ])

  dataset_id = each.value
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_project_service_identity.dataform.email}"
}

# -----------------------------------------------------------------------------
# Dataformリポジトリ
#   git_remote_settings で参照するのは「別リポジトリ」。
#   サブディレクトリ指定はできないため、dataform_project/ は
#   {owner}/{repo} として単独で存在している必要がある（make dataform-push）。
# -----------------------------------------------------------------------------
resource "google_dataform_repository" "main" {
  provider = google-beta
  name     = var.dataform_repo_name
  region   = var.region

  git_remote_settings {
    url                                 = "https://github.com/${var.dataform_github_owner}/${var.dataform_repo_name}.git"
    default_branch                      = var.dataform_git_branch
    authentication_token_secret_version = "${google_secret_manager_secret.this["sec-dataform-github-token"].id}/versions/latest"
  }

  workspace_compilation_overrides {
    default_database = var.gcp_project_id
  }

  labels = { layer = "silver" }

  depends_on = [google_secret_manager_secret_iam_member.dataform_token]
}

# -----------------------------------------------------------------------------
# Release Config : 環境ごとに参照ブランチを紐付ける
#   prd → main / stg → staging / dev → develop
# -----------------------------------------------------------------------------
resource "google_dataform_repository_release_config" "env" {
  provider   = google-beta
  project    = var.gcp_project_id
  region     = var.region
  repository = google_dataform_repository.main.name
  name       = "rc-${var.env}"

  git_commitish = var.dataform_git_branch

  # 日次で最新コードのコンパイル結果を作る（保険）。
  # 実際の実行はWorkflowsから行う（下記のとおり vars を実行ごとに変える必要があるため）。
  cron_schedule = "0 19 * * *" # UTC 19:00 = JST 04:00（日次パイプラインの1時間前）
  time_zone     = "Etc/UTC"

  code_compilation_config {
    default_database = var.gcp_project_id
    default_location = var.bq_location

    # ここの値はプレースホルダ。
    # Workflows が compilationResults.create で etl_ts / batch_id を上書きする
    # （v2/21_transform.md 5.3：workflowInvocations 側に vars は渡せない）。
    vars = {
      env           = var.env
      etl_ts        = "1970-01-01T00:00:00Z"
      batch_id      = "unset"
      window_months = "14"
    }
  }
}

# -----------------------------------------------------------------------------
# ★Workflow Config は意図的に作らない★
#   Dataform内蔵スケジュール（Workflow Config）は vars を実行ごとに変えられないため、
#   監査項目（etl_ts / batch_id）が実行単位で確定できない。
#   本規約では Workflows 経由の起動を標準とする（v2/21_transform.md 5.3）。
# -----------------------------------------------------------------------------
