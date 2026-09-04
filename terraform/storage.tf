# =============================================================================
# storage.tf : GCSバケット
# 規約: v2/13_naming_storage.md
#   - 原本（raw）に Delete ライフサイクルを書かない。SetStorageClass で移行する
#   - uniform_bucket_level_access / public_access_prevention は必須
# =============================================================================

# -----------------------------------------------------------------------------
# 取込ファイルの着地点（原本）
# パス規約: {source_system}/{object}/dt=YYYY-MM-DD/{run_id}/{object}_{ts}.{ext}
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "raw" {
  name                        = local.bucket_raw
  location                    = var.bq_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.env == "dev"

  versioning { enabled = true }

  # 削除ではなくストレージクラスの段階移行（原本は消さない）
  lifecycle_rule {
    condition { age = 90 }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition { age = 365 }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition { age = 1095 }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }

  # 旧バージョンのみ削除対象（現行オブジェクトは削除しない）
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action { type = "Delete" }
  }

  labels = { layer = "bronze" }
}

# -----------------------------------------------------------------------------
# Cloud Functions のソースZIP配置先
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "functions_src" {
  name                        = local.bucket_functions_src
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.env == "dev"

  versioning { enabled = true }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action { type = "Delete" }
  }

  labels = { layer = "common" }
}

# -----------------------------------------------------------------------------
# 生成物（データ辞書・ドキュメントなど）
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "artifacts" {
  name                        = local.bucket_artifacts
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }

  labels = { layer = "common" }
}

# -----------------------------------------------------------------------------
# 一時作業領域（7日で自動削除。後片付けコード不要）
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "tmp" {
  name                        = local.bucket_tmp
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition { age = 7 }
    action { type = "Delete" }
  }

  labels = { layer = "common" }
}

# -----------------------------------------------------------------------------
# 外部システムへの受け渡し
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "export" {
  name                        = local.bucket_export
  location                    = var.bq_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.env == "dev"

  versioning { enabled = true }

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }

  labels = { layer = "gold" }
}
