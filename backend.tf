terraform {
  backend "gcs" {
    bucket = "vc-qa-7968b717b2a4-bucket-tfstate"
    prefix = "terraform/state"
  }
}