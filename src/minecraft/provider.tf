locals {
  s3_region = "minio"
}


provider "kubernetes" {
}

terraform {
  backend "s3" {
    key                         = "k3s/services/minecraft/terraform.tfstate"
    workspace_key_prefix        = "k3s/services/minecraft/env:"
    region                      = "minio"
    bucket                      = "tf-state-files"
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_get_ec2_platforms      = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}


provider "minio" {
  minio_region = "minio"
}
