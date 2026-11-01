#!/usr/bin/env bash
# One-time setup per AWS account:
#   1. S3 bucket for Terraform state (versioned, encrypted, private)
#   2. DynamoDB table for Terraform state locking
#   3. Secrets Manager secret holding your Anthropic API key
# Safe to run again: it skips what already exists.
source "$(dirname "$0")/common.sh"
need aws

ACCOUNT_ID="$(aws_account_id)"
BUCKET="$(state_bucket)"
green "AWS account: $ACCOUNT_ID   Region: $AWS_REGION"

step "1/3 Terraform state bucket: $BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  yellow "Already exists — skipping."
else
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
  fi
  aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$BUCKET" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  green "Created."
fi

step "2/3 Terraform lock table: $LOCK_TABLE"
if aws dynamodb describe-table --table-name "$LOCK_TABLE" >/dev/null 2>&1; then
  yellow "Already exists — skipping."
else
  aws dynamodb create-table --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
  aws dynamodb wait table-exists --table-name "$LOCK_TABLE"
  green "Created."
fi

step "3/3 Anthropic API key in Secrets Manager: $SECRET_NAME"
STATUS="$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query 'DeletedDate' --output text 2>/dev/null || echo MISSING)"
if [ "$STATUS" != "MISSING" ] && [ "$STATUS" != "None" ]; then
  yellow "Secret was scheduled for deletion — restoring it."
  aws secretsmanager restore-secret --secret-id "$SECRET_NAME" >/dev/null
  STATUS="None"
fi
if [ "$STATUS" = "None" ]; then
  read -r -p "Secret already exists. Replace the API key? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { green "Keeping the existing key. Bootstrap complete."; exit 0; }
fi

echo "Paste your Anthropic API key (starts with sk-ant-). Nothing is shown while you paste — that is normal."
read -r -s -p "API key: " API_KEY; echo
API_KEY="$(printf '%s' "$API_KEY" | tr -d '[:space:]')"
[[ "$API_KEY" == sk-ant-* ]] || die "That does not look like an Anthropic key (it must start with sk-ant-). Run this script again."

SECRET_JSON="{\"api_key\":\"$API_KEY\"}"
if [ "$STATUS" = "MISSING" ]; then
  aws secretsmanager create-secret --name "$SECRET_NAME" \
    --description "Anthropic API key for the Nakoba AI Chatbot" \
    --secret-string "$SECRET_JSON" >/dev/null
else
  aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "$SECRET_JSON" >/dev/null
fi
unset API_KEY SECRET_JSON
green "Secret saved. Bootstrap complete — next: ./scripts/deploy.sh dev"
