variable "dataset_id" {
  type        = string
  description = "データセットID（v2/11_naming_bigquery.md 1節: {layer}_{option_name}）"
}

variable "description" {
  type        = string
  description = "データセットの説明。何のデータか・オーナー・連携元を書く"
}

variable "location" {
  type        = string
  description = "ロケーション（全データセットで統一する）"
}

variable "layer" {
  type        = string
  description = "レイヤー（bronze / silver / gold / ops）"

  validation {
    condition     = contains(["bronze", "silver", "gold", "ops"], var.layer)
    error_message = "layer は bronze / silver / gold / ops のいずれか。"
  }
}

variable "option_name" {
  type        = string
  description = "データセット名の {option_name} 部分。IAM境界の可視化に使う"
}

variable "default_table_expiration_ms" {
  type        = number
  description = "テーブルのデフォルト有効期限（ms）。分析用は null（無期限）"
  default     = null
}

variable "readers" {
  type        = list(string)
  description = "参照権限を与えるプリンシパル（例: serviceAccount:sa-transform@...）"
  default     = []
}

variable "writers" {
  type        = list(string)
  description = "編集権限を与えるプリンシパル"
  default     = []
}
