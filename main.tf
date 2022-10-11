#Setup GCP Provider
provider "google" {
  project = var.gcp_project
  region  = "europe-west2"
}

provider "google-beta" {
  project = var.gcp_project
  credentials = var.gcp_creds
  region  = "europe-west2"
}

#Enable required APIs
resource "google_project_service" "serviceusage" {
  project                    = var.gcp_project
  service                    = "serviceusage.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "gcp_resource_manager_api" {
  project = var.gcp_project
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "iam_api" {
  project = var.gcp_project
  service = "iam.googleapis.com"
}

resource "google_project_service" "datastore" {
  project = var.gcp_project
  service = "datastore.googleapis.com"
}

resource "google_project_service" "cloud-run" {
  project = var.gcp_project
  service = "run.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.gcp_project
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "container_registry" {
  project = var.gcp_project
  service = "containerregistry.googleapis.com"
}

resource "google_project_service" "api_gateway" {
  project = var.gcp_project
  service = "apigateway.googleapis.com"
}

resource "google_project_service" "cloud_asset" {
  project = var.gcp_project
  service = "cloudasset.googleapis.com"
}

resource "google_project_service" "service_control" {
  project = var.gcp_project
  service = "servicecontrol.googleapis.com"
}

#Setup API Gateway
resource "google_api_gateway_api" "vc_api" {
  provider = google-beta
  api_id   = "visitor-counter-api"
}

resource "google_api_gateway_api_config" "counter_gwv3" {
  provider      = google-beta
  api           = google_api_gateway_api.vc_api.api_id
  api_config_id = "configv3"

  openapi_documents {
    document {
      path     = "api-configs/${var.api_config}"
      contents = filebase64("api-configs/${var.api_config}")
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.counter_gwv3.id
  gateway_id = "vc-api-gw"
}

resource "google_project_service" "enable_vc_api" {
  project = var.gcp_project
  service = var.vc_api_service
}


resource "google_apikeys_key" "vc_api_key" {
  provider     = google-beta
  name         = "vc-api-key"
  display_name = "Key for the Visitor Counter API"

  restrictions {
    api_targets {
      service = var.vc_api_service
    }
  }
}

#Workload Identity Federation
resource "google_iam_workload_identity_pool" "counter-wi-pool" {
  workload_identity_pool_id = "counter-wi-pool"
  display_name              = "Visitor Counter WI Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_wi_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.counter-wi-pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "service-account-iam" {
  service_account_id = google_service_account.gh_actions_account.id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    var.wif_repo
  ]
  depends_on = [
    google_service_account.gh_actions_account
  ]
}

#Create service accounts and assign roles
resource "google_service_account" "gh_actions_account" {
  account_id   = "github-actions-runner"
  display_name = "GitHub Actions Runner"
}

resource "google_service_account" "tf_service_account" {
  account_id   = "terraform-service-account"
  display_name = "Terraform Service Account"
}

resource "google_project_iam_member" "tf_editor" {
  project = var.gcp_project
  role    = "roles/editor"
  member  = "serviceAccount:terraform-service-account@${var.gcp_project}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud_asset_owner" {
  project = var.gcp_project
  role    = "roles/cloudasset.owner"
  member  = "serviceAccount:github-actions-runner@${var.gcp_project}.iam.gserviceaccount.com"
}

#Cloud Run deploy
resource "google_cloud_run_service" "visitor-counter" {
  name     = "visitor-counter"
  location = "europe-west2"

  metadata {
    annotations = {
      "run.googleapis.com/client-name" = "terraform"
    }
  }

  template {
    spec {
      containers {
        image = "europe-west2-docker.pkg.dev/${var.gcp_project}/visitor-counter/visitor-counter:latest"
      }
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.visitor-counter.location
  project  = google_cloud_run_service.visitor-counter.project
  service  = google_cloud_run_service.visitor-counter.name

  policy_data = data.google_iam_policy.noauth.policy_data

}

# Adding Terraform remote bucket
resource "google_storage_bucket" "default" {
  name          = var.backend
  force_destroy = false
  location      = "EU"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}