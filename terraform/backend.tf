terraform {
  backend "gcs" {
    bucket = "tester-159753-terraform-state"
    prefix = "kpmg-gcp-cram-lab"
  }
}