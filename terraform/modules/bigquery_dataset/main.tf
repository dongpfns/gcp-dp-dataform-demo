# データセット1つ分の共通定義。
# 「作り方」をここに集約し、個別の .tf からは値だけを渡す（v2/40_infra_terraform.md 2節）

resource "google_bigquery_dataset" "this" {
  dataset_id                  = var.dataset_id
  description                 = var.description
  location                    = var.location
  default_table_expiration_ms = var.default_table_expiration_ms

  labels = {
    layer       = var.layer
    option_name = var.option_name
  }

  # データセット単位でIAMを閉じる（v2/30_iam_security.md 3節）
  dynamic "access" {
    for_each = var.readers
    content {
      role          = "READER"
      user_by_email = replace(access.value, "serviceAccount:", "")
    }
  }

  dynamic "access" {
    for_each = var.writers
    content {
      role          = "WRITER"
      user_by_email = replace(access.value, "serviceAccount:", "")
    }
  }

  # 作成者（Terraform実行SA）のOWNER権限は必ず残す
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
}
