terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
  backend "gcs" {
      bucket  = "testcmdep_job_states"
      prefix  = "safe_k8s"
      credentials = "test-cm-project-19ff050b3e40.json"
    }
}

provider "google" {
  credentials = file(var.creds_file)
  project = var.project_id
  region = var.region
}

provider "google-beta" {
  credentials = file(var.creds_file)
  project = var.project_id
  region = var.region
}
