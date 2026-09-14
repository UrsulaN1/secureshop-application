# US-008: Terraform remote state, not committed to Git, with locking.
# Bootstrap the bucket/table once (see scripts/bootstrap-backend.sh) then
# uncomment / fill in the backend block below and run `terraform init -migrate-state`.
terraform {
  backend "s3" {
    bucket         = "secureshop-tfstate-<ACCOUNT_ID>"
    key            = "secureshop/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "secureshop-tf-locks"
    encrypt        = true
  }
}
