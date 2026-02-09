terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.30"
    }
  }

  # Bootstrap uses local backend — its state is managed manually
}

provider "aws" {
  region = var.aws_region
}
