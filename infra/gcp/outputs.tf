output "api_url" {
  description = "Deterministic Cloud Run URL of the API server."
  value       = "https://${local.api_host}"
}

output "image_repo" {
  description = "Artifact Registry path for server images."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.server.repository_id}"
}

output "sql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)."
  value       = google_sql_database_instance.pg.connection_name
}

output "blob_bucket" {
  description = "Private GCS bucket for photos, covers and avatars."
  value       = google_storage_bucket.blobs.name
}
