data "google_project" "project" {}

provider "google" {
  credentials = file("../hamilius-511324b08e84.json")
  project = var.project_id
  region  = var.region_name
}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "source_bucket" {
  name                        = "${data.google_project.project.project_id}-${random_id.bucket_prefix.hex}-gcf-source-bucket"
  location                    = var.region_name
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "/tmp/function-source.zip"
  source_dir  = "../function-source/"
}

resource "google_storage_bucket_object" "default" {
  name   = "function-source_${data.archive_file.default.output_sha256}.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.default.output_path # Path to the zipped function source code
}

resource "google_storage_bucket" "trigger_bucket" {
  name                        = "${data.google_project.project.project_id}-${random_id.bucket_prefix.hex}-gcf-trigger-bucket"
  location = var.region_name # The trigger must be in the same location as the bucket
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "google_storage_project_service_account" "default" {}

resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = data.google_project.project.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.default.email_address}"
}

resource "google_service_account" "account" {
  account_id   = "gcf-sa"
  display_name = "Service Account - used for both the cloud function and eventarc trigger in the test"
}

resource "google_project_iam_member" "invoking" {
  project = data.google_project.project.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.account.email}"
  depends_on = [google_project_iam_member.gcs_pubsub_publishing]
}

resource "google_project_iam_member" "logWriter" {
  project = data.google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.account.email}"
}

resource "google_project_iam_member" "developer" {
  project = data.google_project.project.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.account.email}"
}

resource "google_project_iam_member" "serviceAccountUser" {
  project = data.google_project.project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.account.email}"
}

resource "google_project_iam_member" "event_receiving" {
  project = data.google_project.project.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.account.email}"
  depends_on = [google_project_iam_member.invoking]
}

resource "google_project_iam_member" "artifactregistry_reader" {
  project = data.google_project.project.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.account.email}"
  depends_on = [google_project_iam_member.event_receiving]
}

resource "google_project_iam_member" "artifactregistry_admin" {
  project = data.google_project.project.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.account.email}"
}


resource "google_project_iam_member" "cloud_storage_reader" {
  project = data.google_project.project.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.account.email}"
  depends_on = [google_project_iam_member.event_receiving]
}

resource "google_project_iam_member" "firestore_user" {
  project = data.google_project.project.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.account.email}"
}

resource "google_cloud_run_service_iam_binding" "cloud_run_service_invokers" {
  location = google_cloud_run_v2_service.flask-api-service.location
  service  = google_cloud_run_v2_service.flask-api-service.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

resource "google_firestore_database" "database" {
  name        = "${data.google_project.project.project_id}-${random_id.bucket_prefix.hex}-one"
  location_id = "europe-west1"
  type        = "FIRESTORE_NATIVE"
}

resource "google_firestore_document" "mydoc" {
  project     = data.google_project.project.project_id
  database    = google_firestore_database.database.name
  collection  = "processed_files"
  document_id = "my-test-doc-${random_id.bucket_prefix.hex}"
  fields      = "{\"something\":{\"mapValue\":{\"fields\":{\"akey\":{\"stringValue\":\"avalue\"}}}}}"
}

module "google_cloud_function_triggered_by_object_storage_put" {
  source                     = "./modules/google_cloud_function"
  cloud_function_name        = "process_customer_files3"
  cloud_function_description = "a new desc"
  cloud_function_entrypoint  = "process_customer_file"
  firestore_collection_name  = google_firestore_document.mydoc.collection
  firestore_database_name    = google_firestore_database.database.name
  firestore_project_id       = data.google_project.project.project_id
  service_account_email      = google_service_account.account.email
  source_bucket_name         = google_storage_bucket.source_bucket.name
  source_bucket_object_name  = google_storage_bucket_object.default.name
  trigger_bucket_name        = google_storage_bucket.trigger_bucket.name
  depends_on = [
    google_project_iam_member.event_receiving,
    google_project_iam_member.artifactregistry_reader,
  ]
}
resource "google_cloud_run_v2_service" "flask-api-service" {
  name     = "${var.project_id}--flask-api-service"
  location = var.region_name
  deletion_protection = false
  template {
    containers {
      image = "europe-west1-docker.pkg.dev/hamilius/hamilius-docker-repo/flask-api-image"
      env {
        name  = "FIRESTORE_COLLECTION"
        value = "processed_file"
      }
      env {
        name  = "FIRESTORE_DATABASE_NAME"
        value = google_firestore_database.database.name
      }
      env {
        name = "FIRESTORE_PROJECT_ID"
        value = data.google_project.project.project_id
      }
      startup_probe {
        failure_threshold     = 5
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 3

        http_get {
          path = "/ping"
          http_headers {
            name  = "Access-Control-Allow-Origin"
            value = "*"
          }
        }
      }

    }
  }
}

resource "google_api_gateway_api" "flask-api-service_api_cfg" {
  project     = data.google_project.project.project_id
  provider = google-beta
  api_id = "flask-api-service-api-gateway"
}

resource "google_api_gateway_api_config" "flask-api-service_api_cfg" {
  provider = google-beta
  project     = data.google_project.project.project_id
  api = google_api_gateway_api.flask-api-service_api_cfg.api_id
  api_config_id = "flask-api-service-api-gateway-api-config"

  openapi_documents {
    document {
      path = "spec.yaml"
      contents = filebase64("../openapi2-run.yaml")
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider = google-beta
  project     = data.google_project.project.project_id
  api_config = google_api_gateway_api_config.flask-api-service_api_cfg.id
  gateway_id = "flask-api-service-gateway-gateway"
  region = var.region_name
}