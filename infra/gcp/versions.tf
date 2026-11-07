terraform {
  required_version = ">= 1.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Created by bootstrap.sh.
  backend "gcs" {
    bucket = "story-line-tfstate"
    prefix = "prod"
  }
}
