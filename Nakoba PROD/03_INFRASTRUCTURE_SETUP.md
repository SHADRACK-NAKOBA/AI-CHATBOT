# Infrastructure Setup Guide

## Prerequisites

Before provisioning infrastructure, ensure you have:

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | >= 2.0 | https://aws.amazon.com/cli/ |
| Node.js | >= 20.0 | https://nodejs.org |
| Git | Any | https://git-scm.com |
| npm | >= 10.0 | Bundled with Node.js |

---

## Step 1 — AWS Account Setup

### 1a. Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID: [your key]
# AWS Secret Access Key: [your secret]
# Default region: us-east-1
# Default output format: json
```

### 1b. Verify Identity

```bash
aws sts get-caller-identity
# Should return your AccountId and UserId
```

### 1c. Required IAM Permissions for Terraform Operator

The person running Terraform needs these AWS permissions:
- `lambda:*`
- `apigateway:*`
- `s3:*`
- `dynamodb:*`
- `cloudfront:*`
- `wafv2:*`
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`, `iam:PassRole`
- `secretsmanager:*`
- `cloudwatch:*`
- `logs:*`
- `budgets:*`

> **Recommendation:** Create a dedicated `terraform-operator` IAM user with these permissions only. Never use root credentials.

---

## Step 2 — Terraform State Backend Setup

Terraform state must be stored remotely and encrypted. Run this ONCE before `terraform init`:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://nakoba-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket nakoba-terraform-state-[ACCOUNT_ID] \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket nakoba-terraform-state-[ACCOUNT_ID] \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name nakoba-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Step 3 — Store the Anthropic API Key in Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "nakoba/anthropic-api-key" \
  --description "Anthropic API key for Nakoba AI Chatbot" \
  --secret-string '{"api_key":"sk-ant-YOUR_KEY_HERE"}' \
  --region us-east-1
```

> **Security:** Never put the actual key in a shell script file. Type it interactively or pipe from a password manager.

---

## Step 4 — Configure GitHub Actions Secrets

In your GitHub repository → Settings → Secrets and Variables → Actions, add:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Terraform operator access key |
| `AWS_SECRET_ACCESS_KEY` | Terraform operator secret key |
| `AWS_REGION` | `us-east-1` |
| `ANTHROPIC_API_KEY` | Your Anthropic API key (for CI test only) |
| `SNYK_TOKEN` | Your Snyk API token (for security scanning) |

---

## Step 5 — Deploy Infrastructure with Terraform

### 5a. Initialize Terraform

```bash
cd terraform/

# Initialize with remote backend (update bucket name)
terraform init \
  -backend-config="bucket=nakoba-terraform-state-[ACCOUNT_ID]" \
  -backend-config="key=nakoba-chatbot/prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=nakoba-terraform-locks"
```

### 5b. Validate Configuration

```bash
terraform validate
terraform fmt -check
```

### 5c. Plan — Review Changes Before Applying

```bash
# For development
terraform plan -var-file="environments/dev.tfvars" -out=dev.plan

# For staging
terraform plan -var-file="environments/staging.tfvars" -out=staging.plan

# For production (always review thoroughly)
terraform plan -var-file="environments/prod.tfvars" -out=prod.plan
```

**Review the plan output carefully.** Confirm:
- No unexpected resource deletions
- Correct environment tags
- Correct region
- Budget limits are set

### 5d. Apply

```bash
# Apply the saved plan (recommended — exact same changes that were reviewed)
terraform apply dev.plan
```

### 5e. Capture Outputs

```bash
terraform output
# cloudfront_domain    = "d1234567890.cloudfront.net"
# api_gateway_url      = "https://abc123.execute-api.us-east-1.amazonaws.com"
# lambda_function_name = "nakoba-chatbot-prod"
```

---

## Step 6 — Build and Deploy Lambda

```bash
cd ai-chatbot/lambda/

# Install production dependencies only
npm install --production

# Package Lambda
zip -r ../../terraform/lambda.zip . -x "*.test.js" -x "test.js" -x "*.zip"

# Update Lambda code (after first Terraform apply creates the function)
aws lambda update-function-code \
  --function-name nakoba-chatbot-prod \
  --zip-file fileb://../../terraform/lambda.zip \
  --region us-east-1
```

> In production, this step is automated by the CD pipeline.

---

## Step 7 — Deploy Frontend

```bash
# Get CloudFront domain from Terraform outputs
CLOUDFRONT_DOMAIN=$(cd terraform && terraform output -raw cloudfront_domain)
S3_BUCKET=$(cd terraform && terraform output -raw frontend_bucket_name)

# Inject API Gateway URL into frontend
API_URL=$(cd terraform && terraform output -raw api_gateway_url)
sed -i "s|YOUR_API_GATEWAY_URL|${API_URL}|g" ai-chatbot/frontend/index.html

# Upload to S3
aws s3 cp ai-chatbot/frontend/index.html s3://${S3_BUCKET}/index.html \
  --content-type "text/html" \
  --cache-control "max-age=3600"

# Invalidate CloudFront cache
DISTRIBUTION_ID=$(cd terraform && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

---

## Step 8 — Verify Deployment

```bash
# Test health endpoint
curl https://${CLOUDFRONT_DOMAIN}/health

# Test chat endpoint
curl -X POST https://${CLOUDFRONT_DOMAIN}/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, are you working?"}'
```

Expected responses:
- Health: `{"status": "healthy", "timestamp": "...", "version": "2.0.0"}`
- Chat: `{"response": "...", "tokens": {...}}`

---

## Teardown (Destroy All Resources)

```bash
# CAUTION: This destroys all resources. Confirm environment before running.
terraform destroy -var-file="environments/prod.tfvars"

# Type "yes" when prompted
```

> **Warning:** DynamoDB deletion protection is enabled in prod. Remove it first:
> ```bash
> aws dynamodb update-table --table-name nakoba-rate-limits-prod \
>   --deletion-protection-enabled false
> ```

---

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| `AccessDeniedException` | IAM role missing permission | Check Lambda execution role policy |
| `ResourceNotFoundException` | Secrets Manager secret doesn't exist | Run Step 3 |
| Lambda timeout | Cold start + API latency | Increase timeout to 30s in `lambda.tf` |
| WAF blocking legitimate requests | Rule group false positive | Check WAF sampled requests, add exclusion |
| CloudFront returning stale content | Cache not invalidated | Run `aws cloudfront create-invalidation` |
| Terraform state lock | Previous run crashed | `terraform force-unlock [LOCK_ID]` |
