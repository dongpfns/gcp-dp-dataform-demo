output "table_id" {
  description = "作成したテーブルID"
  value       = google_bigquery_table.this.table_id
}

output "full_table_id" {
  description = "project.dataset.table 形式のフルID"
  value       = "${google_bigquery_table.this.project}.${google_bigquery_table.this.dataset_id}.${google_bigquery_table.this.table_id}"
}
