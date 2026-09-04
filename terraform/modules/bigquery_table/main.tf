# テーブル1つ分の共通定義。
# 列定義（中身）は schemas/*.json 側に置き、ここには「作り方」だけを書く。

resource "google_bigquery_table" "this" {
  dataset_id  = var.dataset_id
  table_id    = var.table_id
  description = var.description
  schema      = file(var.schema_file)

  deletion_protection = var.deletion_protection

  labels = {
    layer       = var.layer
    option_name = var.option_name
  }

  # パーティション列が指定された場合のみ設定する
  dynamic "time_partitioning" {
    for_each = var.partition_field == null ? [] : [1]
    content {
      type                     = var.partition_granularity
      field                    = var.partition_field
      require_partition_filter = var.require_partition_filter
    }
  }

  clustering = length(var.clustering) > 0 ? var.clustering : null

  lifecycle {
    # 粒度・パーティション列の変更は replace が必要になるため、
    # 意図しない再作成を防ぐ。変更する場合は明示的に terraform state を操作する。
    prevent_destroy = false
  }
}
