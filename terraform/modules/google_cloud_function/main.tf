resource "google_cloudfunctions2_function" "default" {
  name        = var.cloud_function_name
  location    = var.region
  description = "a new function"

  build_config {
    runtime     = var.cloud_function_runtime
    entry_point = var.cloud_function_entrypoint
    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }
    source {
      storage_source {
        bucket = var.source_bucket_name
        object = var.source_bucket_object_name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
      FIRESTORE_DATABASE_NAME = var.firestore_database_name
      FIRESTORE_COLLECTION_NAME = var.firestore_collection_name
      FIRESTORE_PROJECT_ID = var.firestore_project_id
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = var.service_account_email
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.service_account_email
    event_filters {
      attribute = "bucket"
      value     = var.trigger_bucket_name
    }
  }
}