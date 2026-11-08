provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  # Cloud Run's deterministic URL: <service>-<project number>.<region>.run.app
  api_host = "story-line-api-${data.google_project.this.number}.${var.region}.run.app"

  services = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "storage.googleapis.com",
    # Signs the browsers' direct-upload URLs for the photo bucket (IAM signBlob).
    "iamcredentials.googleapis.com",
  ])

  # Generated secrets: key => { secret id, env var on the API container }.
  generated_secrets = {
    db             = { id = "story-line-db-password", env = "SERVERPOD_DATABASE_PASSWORD" }
    service_secret = { id = "story-line-service-secret", env = "SERVERPOD_SERVICE_SECRET" }
    email_pepper   = { id = "story-line-email-pepper", env = "SERVERPOD_PASSWORD_emailSecretHashPepper" }
    jwt_key        = { id = "story-line-jwt-key", env = "SERVERPOD_PASSWORD_jwtHmacSha512PrivateKey" }
    refresh_pepper = { id = "story-line-refresh-pepper", env = "SERVERPOD_PASSWORD_jwtRefreshTokenHashPepper" }
  }

  # Resend secrets are created by bootstrap.sh so their values stay out of Terraform state.
  resend_secrets = {
    resend_api_key = { id = "story-line-resend-api-key", env = "SERVERPOD_PASSWORD_resendApiKey" }
    resend_from    = { id = "story-line-resend-from", env = "SERVERPOD_PASSWORD_resendFrom" }
  }

  secret_env = merge(
    { for k, s in local.generated_secrets : s.env => google_secret_manager_secret.generated[k].secret_id },
    { for k, s in local.resend_secrets : s.env => data.google_secret_manager_secret.resend[k].secret_id },
  )
}

resource "google_project_service" "this" {
  for_each           = local.services
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "server" {
  location      = var.region
  repository_id = "story-line"
  format        = "DOCKER"

  depends_on = [google_project_service.this]
}

resource "google_service_account" "api" {
  account_id   = "story-line-api"
  display_name = "Story Line API (Cloud Run)"

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "api_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# --- Blob storage (photos, covers, avatars) ----------------------------------

# Private; every read goes through the API's media endpoint. Browsers PUT
# photos and covers straight to signed URLs, hence CORS for the web origin.
# No lifecycle rule: blobs are deleted by the server's blob outbox.
resource "google_storage_bucket" "blobs" {
  name                        = "${var.project_id}-blobs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  cors {
    origin          = [var.web_origin]
    method          = ["PUT"]
    response_header = ["Content-Type", "x-goog-content-length-range", "x-goog-if-generation-match"]
    max_age_seconds = 3600
  }

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_iam_member" "api_blobs" {
  bucket = google_storage_bucket.blobs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.api.email}"
}

# The API has no key file: it signs upload URLs as itself through IAM signBlob.
resource "google_service_account_iam_member" "api_sign_self" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.api.email}"
}

# --- Cloud SQL --------------------------------------------------------------

resource "google_sql_database_instance" "pg" {
  name                = "story-line-pg"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = true

  settings {
    tier            = "db-f1-micro"
    edition         = "ENTERPRISE"
    disk_type       = "PD_SSD"
    disk_size       = 10
    disk_autoresize = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    # Public IP with no authorized networks: only the Cloud SQL connector
    # (Cloud Run volume) can reach it.
    ip_configuration {
      ipv4_enabled = true
    }
  }

  depends_on = [google_project_service.this]
}

resource "google_sql_database" "app" {
  name     = "story_line"
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "app" {
  name     = "story_line"
  instance = google_sql_database_instance.pg.name
  password = random_password.generated["db"].result
}

# --- Secrets ----------------------------------------------------------------

resource "random_password" "generated" {
  for_each = {
    db             = 32
    service_secret = 64
    email_pepper   = 64
    jwt_key        = 128
    refresh_pepper = 64
  }
  length  = each.value
  special = false
}

resource "google_secret_manager_secret" "generated" {
  for_each  = local.generated_secrets
  secret_id = each.value.id

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

resource "google_secret_manager_secret_version" "generated" {
  for_each    = local.generated_secrets
  secret      = google_secret_manager_secret.generated[each.key].id
  secret_data = random_password.generated[each.key].result
}

data "google_secret_manager_secret" "resend" {
  for_each  = local.resend_secrets
  secret_id = each.value.id
}

resource "google_secret_manager_secret_iam_member" "api" {
  for_each  = local.secret_env
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# --- Cloud Run --------------------------------------------------------------

resource "google_cloud_run_v2_service" "api" {
  name                = "story-line-api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account       = google_service_account.api.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    # Long-lived live-stream websockets.
    timeout                          = "3600s"
    max_instance_request_concurrency = 80

    # No Redis: live streams fan out in-process and future calls need a
    # running CPU, so exactly one always-on instance.
    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.pg.connection_name]
      }
    }

    containers {
      # Placeholder; real images are rolled out by `just deploy-server`.
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      # Migrations run on start. 10 s × 24 = 240 s, Cloud Run's startup limit.
      startup_probe {
        tcp_socket {
          port = 8080
        }
        period_seconds    = 10
        failure_threshold = 24
      }

      env {
        name  = "SERVERPOD_API_SERVER_PUBLIC_HOST"
        value = local.api_host
      }
      env {
        name  = "SERVERPOD_DATABASE_HOST"
        value = "/cloudsql/${google_sql_database_instance.pg.connection_name}/.s.PGSQL.5432"
      }
      env {
        name  = "SERVERPOD_PASSWORD_inviteAppOrigin"
        value = var.web_origin
      }
      env {
        name  = "SERVERPOD_PASSWORD_gcsBucket"
        value = google_storage_bucket.blobs.name
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }

  depends_on = [
    google_secret_manager_secret_version.generated,
    google_secret_manager_secret_iam_member.api,
    google_project_iam_member.api_cloudsql_client,
    google_storage_bucket_iam_member.api_blobs,
    google_service_account_iam_member.api_sign_self,
    google_sql_database.app,
    google_sql_user.app,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
