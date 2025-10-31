terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    jenkins = {
      source  = "yarlson/jenkins"
      version = "0.9.10"
    }
  }
#   backend "s3" {
#     bucket         = "my-terraform-state-bucket"
#     key            = "terraform/state"
#     region        = "us-east-1"
# access_key = "AKIAWAA66MJUNJFOWSAU"
# secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

    #   }
}

provider "aws" {
  region = var.aws_region
  #access_key = "AKIAWAA66MJUNJFOWSAU"
  #secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# NOTE: Do NOT hard-code credentials. Configure AWS credentials via environment
# variables, the shared credentials file (~/.aws/credentials), or an assumed role.

provider "jenkins" {
  server_url = "http://157.119.43.36:9080"
  username = "admin"
  password = "Reset123"
}