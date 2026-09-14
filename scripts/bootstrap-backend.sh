#!/usr/bin/env bash
# US-008: one-time bootstrap of the Terraform remote state backend (S3 + DynamoDB lock table).
# Run this ONCE, before `terraform init`, using an admin/bootstrap AWS profile.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="secureshop-tfstate-${ACCOUNT_ID}"
TABLE="secureshop-tf-locks"

aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  $( [ "$REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$REGION" )

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "Backend ready: bucket=$BUCKET table=$TABLE"
echo "Update terraform/backend.tf with bucket=$BUCKET before running terraform init."
