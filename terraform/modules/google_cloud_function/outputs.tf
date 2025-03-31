output "google_cloud_function_name" {
  description = "Name of google cloud function"
  value = google_cloudfunctions2_function.default.name
}

output "google_cloud_function_description" {
  description = "Description of google cloud function"
  value = google_cloudfunctions2_function.default.description
}

output "google_cloud_function_entrypoint" {
  description = "Entrypoint of google cloud function"
  value = google_cloudfunctions2_function.default.build_config[0].entry_point
}

output "google_cloud_function_location" {
  description = "Location of google cloud function"
  value = google_cloudfunctions2_function.default.location
}