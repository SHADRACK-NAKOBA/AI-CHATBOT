terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    # Configure via -backend-config flags in terraform init
    # bucket         = "nakoba-terraform-state-[ACCOUNT_ID]"
    # key            = "nakoba-chatbot/[env]/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "nakoba-terraform-locks"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront and WAF for CloudFront must use us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner_email
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
    DataClass   = "confidential"
    CreatedDate = "2026-05-27"
  }
}
