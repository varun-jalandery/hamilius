

variable "region" {
  description = "Region"
  type = string
  default = "europe-west1"
}

variable "cloud_function_name" {
  description = "Name of the cloud function"
  type = string
}

variable "cloud_function_description" {
  description = "Description of the cloud function"
  type = string
  default = "Description of the cloud function"
}
variable "cloud_function_entrypoint" {
  description = "Name of the cloud function entrypoint"
  type = string
}

variable "cloud_function_runtime" {
  description = "Runtime of the cloud function"
  type = string
  default = "python312"
}
variable "source_bucket_name" {
  description = "Bucket where to store the function"
  type = string
}

variable "trigger_bucket_name" {
  description = "Bucket where to store the trigger"
  type = string
}
variable "source_bucket_object_name" {
  description = "Name of the zip file"
  type = string
}

variable "firestore_database_name" {
  description = "Name of the firestore database"
  type = string
}

variable "firestore_collection_name" {
  description = "Name of the firestore collection"
  type = string
}

variable "firestore_project_id" {
  description = "Project ID of the firestore database"
  type = string
}

variable "service_account_email" {
  description = "Service account email"
  type = string
}