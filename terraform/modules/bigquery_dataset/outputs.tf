output "dataset_id" {
  description = "作成したデータセットID"
  value       = google_bigquery_dataset.this.dataset_id
}

output "self_link" {
  description = "データセットのself link"
  value       = google_bigquery_dataset.this.self_link
}
