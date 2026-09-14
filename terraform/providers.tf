provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SecureShop"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
