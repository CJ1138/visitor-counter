#TODO - Lockdown access to Cloud Run service to only API Gateway (currently public)

#Setup GCP Provider
provider "google" {
  project = "visitor-counter-qa"
  region  = "europe-west2"
}

provider "google-beta" {
  credentials = "visitor-counter-qa-1c59151f64a6.json"
  project     = "visitor-counter-qa"
  region      = "europe-west2"
}

#Enable required APIs
resource "google_project_service" "serviceusage" {
  project                    = "visitor-counter-qa"
  service                    = "serviceusage.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "gcp_resource_manager_api" {
  project = "visitor-counter-qa"
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "iam_api" {
  project = "visitor-counter-qa"
  service = "iam.googleapis.com"
}

resource "google_project_service" "datastore" {
  project = "visitor-counter-qa"
  service = "datastore.googleapis.com"
}

resource "google_project_service" "cloud-run" {
  project = "visitor-counter-qa"
  service = "run.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = "visitor-counter-qa"
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "container_registry" {
  project = "visitor-counter-qa"
  service = "containerregistry.googleapis.com"
}

resource "google_project_service" "api_gateway" {
  project = "visitor-counter-qa"
  service = "apigateway.googleapis.com"
}

resource "google_project_service" "cloud_asset" {
  project = "visitor-counter-qa"
  service = "cloudasset.googleapis.com"
}

resource "google_project_service" "service_control" {
  project = "visitor-counter-qa"
  service = "servicecontrol.googleapis.com"
}

#Setup API Gateway
resource "google_api_gateway_api" "vc_api" {
  provider = google-beta
  api_id   = "visitor-counter-api"
}

resource "google_api_gateway_api_config" "counter_gwv2" {
  provider      = google-beta
  api           = google_api_gateway_api.vc_api.api_id
  api_config_id = "configv2"

  openapi_documents {
    document {
      path     = "api-configs/qa-config.yaml"
      contents = filebase64("api-configs/qa-config.yaml")
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider   = google-beta
  api_config = "projects/300165146813/locations/global/apis/visitor-counter-api/configs/configv2"
  gateway_id = "vc-api-gw"
}

resource "google_project_service" "enable_vc_api" {
  project = "visitor-counter-qa"
  service = "visitor-counter-api-2tede7yicnc9f.apigateway.visitor-counter-qa.cloud.goog"
}

resource "google_apikeys_key" "vc_api_key" {
  provider     = google-beta
  name         = "vc-api-key"
  display_name = "Key for the Visitor Counter API"

  restrictions {
    api_targets {
      service = "visitor-counter-api-2tede7yicnc9f.apigateway.visitor-counter-qa.cloud.goog"
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
  service_account_id = "projects/visitor-counter-qa/serviceAccounts/github-actions-runner@visitor-counter-qa.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/projects/300165146813/locations/global/workloadIdentityPools/counter-wi-pool/attribute.repository/CJ1138/crc"
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
  project = "visitor-counter-qa"
  role    = "roles/editor"
  member  = "serviceAccount:terraform-service-account@visitor-counter-qa.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud_asset_owner" {
  project = "visitor-counter-qa"
  role    = "roles/cloudasset.owner"
  member  = "serviceAccount:github-actions-runner@visitor-counter-qa.iam.gserviceaccount.com"
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
        image = "europe-west2-docker.pkg.dev/visitor-counter-qa/visitor-counter/visitor-counter:latest"
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
  name          = "vc-qa-7968b717b2a4-bucket-tfstate"
  force_destroy = false
  location      = "EU"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}