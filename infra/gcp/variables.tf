variable "project_id" {
  description = "GCP project that hosts Story Line."
  type        = string
  default     = "story-line"
}

variable "region" {
  description = "Region for Cloud Run, Cloud SQL and Artifact Registry."
  type        = string
  default     = "us-central1"
}

variable "web_origin" {
  description = "Origin serving the Flutter web app (Firebase Hosting); used in invite links."
  type        = string
  default     = "https://story-line.web.app"
}
