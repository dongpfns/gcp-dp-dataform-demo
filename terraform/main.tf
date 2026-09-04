# =============================================================================
# main.tf : プロバイダ / backend / API有効化
# 規約: v2/40_infra_terraform.md
# =============================================================================

terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }

  # bucket は scripts/tf.sh が -backend-config で環境ごとに注入する
  backend "gcs" {
    prefix = "platform"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.region

  # 全リソースにラベルを一括付与（v2/12_naming_gcp_resources.md 6節）
  default_labels = local.common_labels
}

provider "google-beta" {
  project        = var.gcp_project_id
  region         = var.region
  default_labels = local.common_labels
}

# -----------------------------------------------------------------------------
# 有効化するAPI（v2/40_infra_terraform.md 9節）
# disable_on_destroy = false : destroy時に他システムのAPIまで止めない
# -----------------------------------------------------------------------------
locals {
  required_apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "workflows.googleapis.com",
    "workflowexecutions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "pubsub.googleapis.com",
    "dataform.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each = toset(local.required_apis)

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}
