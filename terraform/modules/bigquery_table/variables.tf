variable "dataset_id" {
  type        = string
  description = "テーブルを作成するデータセットID"
}

variable "table_id" {
  type        = string
  description = "テーブル名（v2/11_naming_bigquery.md 2節: d_ / f_{grain}_ / t_）"
}

variable "description" {
  type        = string
  description = "テーブルの説明"
}

variable "schema_file" {
  type        = string
  description = "列定義JSONのパス（schemas/{dataset}/{table}.json）"
}

variable "layer" {
  type        = string
  description = "レイヤー（bronze / silver / gold）"
}

variable "option_name" {
  type        = string
  description = "データセットの {option_name}"
}

# -----------------------------------------------------------------------------
# パーティション
# 規約: 粒度を DAY 固定にせず変数として外に出す（v2/11_naming_bigquery.md 3.1）
#       粒度の変更は apply では反映できない（replace が必要）
# -----------------------------------------------------------------------------
variable "partition_field" {
  type        = string
  description = "パーティション列。ファクトは必須、ディメンションは null"
  default     = null
}

variable "partition_granularity" {
  type        = string
  description = "パーティション粒度（DAY / MONTH / YEAR）。10年以上保持は MONTH"
  default     = "MONTH"

  validation {
    condition     = contains(["DAY", "MONTH", "YEAR"], var.partition_granularity)
    error_message = "partition_granularity は DAY / MONTH / YEAR のいずれか。"
  }
}

variable "require_partition_filter" {
  type        = bool
  description = "パーティションフィルタを必須にする（フルスキャン事故の防止）"
  default     = true
}

variable "clustering" {
  type        = list(string)
  description = "クラスタ列（最大4列）。ディメンションは必須。MONTHパーティションでは基準日列を先頭に置く"
  default     = []

  validation {
    condition     = length(var.clustering) <= 4
    error_message = "clustering は最大4列。"
  }
}

variable "deletion_protection" {
  type        = bool
  description = "削除保護。本番のSILVER/GOLDは true"
  default     = true
}
