#!/usr/bin/env bash

set -euo pipefail

# ==========================================================
# SecureShop Terraform Backend Bootstrap
# Creates/configures the S3 bucket used for:
#   - Terraform remote state
#   - Terraform native S3 state locking (.tflock)
# ==========================================================

REGION="${AWS_REGION:-us-east-1}"

BUCKET="secureshop-bucket1"

STATE_KEY="secureshop/dev/terraform.tfstate"


echo "=================================================="
echo " SecureShop Terraform Backend Bootstrap"
echo "=================================================="
echo "Region:     $REGION"
echo "S3 Bucket:  $BUCKET"
echo "State Key:  $STATE_KEY"
echo "=================================================="
echo ""


# ----------------------------------------------------------
# Verify AWS authentication
# ----------------------------------------------------------

echo "Checking AWS authentication..."

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)

echo "Authenticated AWS Account: $ACCOUNT_ID"
echo ""


# ----------------------------------------------------------
# Create S3 bucket if it does not exist
# ----------------------------------------------------------

echo "Checking Terraform state bucket: $BUCKET"

if aws s3api head-bucket \
    --bucket "$BUCKET" \
    2>/dev/null; then

    echo "S3 bucket already exists: $BUCKET"
    echo "Skipping bucket creation."

else

    echo "Creating Terraform state bucket: $BUCKET"

    if [ "$REGION" = "us-east-1" ]; then

        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION"

    else

        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION" \
            --create-bucket-configuration \
            LocationConstraint="$REGION"

    fi

    echo "S3 bucket created successfully."

fi

echo ""


# ----------------------------------------------------------
# Enable S3 bucket versioning
# ----------------------------------------------------------

echo "Enabling S3 bucket versioning..."

aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

echo "Bucket versioning enabled."
echo ""


# ----------------------------------------------------------
# Enable server-side encryption
# ----------------------------------------------------------

echo "Enabling server-side encryption..."

aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration \
    '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

echo "Bucket encryption enabled."
echo ""


# ----------------------------------------------------------
# Block all public access
# ----------------------------------------------------------

echo "Blocking public access..."

aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Public access blocked."
echo ""


# ----------------------------------------------------------
# Verify bucket versioning
# ----------------------------------------------------------

echo "Verifying bucket versioning..."

VERSIONING_STATUS=$(aws s3api get-bucket-versioning \
    --bucket "$BUCKET" \
    --query Status \
    --output text)

echo "Versioning status: $VERSIONING_STATUS"
echo ""


# ----------------------------------------------------------
# Verify bucket encryption
# ----------------------------------------------------------

echo "Verifying bucket encryption..."

aws s3api get-bucket-encryption \
    --bucket "$BUCKET" \
    >/dev/null

echo "Encryption configured successfully."
echo ""


# ----------------------------------------------------------
# Complete
# ----------------------------------------------------------

echo "=================================================="
echo " Terraform Backend Ready"
echo "=================================================="
echo "AWS Account: $ACCOUNT_ID"
echo "AWS Region:  $REGION"
echo "S3 Bucket:   $BUCKET"
echo "State File:  s3://$BUCKET/$STATE_KEY"
echo "Lock File:   s3://$BUCKET/${STATE_KEY}.tflock"
echo "=================================================="
echo ""

echo "Use the following configuration in terraform/backend.tf:"
echo ""

cat <<EOF
terraform {
  backend "s3" {
    bucket       = "$BUCKET"
    key          = "$STATE_KEY"
    region       = "$REGION"
    use_lockfile = true
    encrypt      = true
  }
}
EOF

echo ""
echo "Then initialize Terraform:"
echo ""
echo "  terraform init -reconfigure"
echo ""