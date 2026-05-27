# Deployment Runbook — Production

**This is the authoritative step-by-step guide for deploying the Nakoba AI Chatbot to production.**

---

## Pre-Deployment Checklist

Before every production deployment, confirm all of the following:

```
□ All CI pipeline checks pass (GitHub Actions CI green)
□ Staging deployment is healthy (smoke tests pass)
□ Staging has been running for at least 30 minutes without alarms
□ Production deployment has been approved by 2 reviewers in GitHub
□ The change has been communicated to stakeholders (if user-visible)
□ Rollback plan is understood and commands are ready
□ Slack #deployments channel is being monitored
□ AWS Cost Explorer checked — no anomaly in last 24 hours
```

---

## Deployment Steps

### Step 1 — Trigger Production Deployment

Via GitHub Actions (preferred):
1. Navigate to: GitHub → Actions → CD Production
2. Click "Run workflow"
3. Select branch: `main`
4. Confirm environment: `production`
5. Click "Run workflow"

Monitor progress in GitHub Actions UI.

### Step 2 — Monitor During Deployment (10-15 minutes)

Open in parallel:
- GitHub Actions UI — track pipeline steps
- CloudWatch Dashboard: `nakoba-chatbot-prod` — watch for error spikes
- CloudWatch Alarms — check none fire during deploy

### Step 3 — Post-Deployment Smoke Tests

```bash
# Set variables
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain -chdir=terraform)

# Test 1: Health check
curl -sf https://${CLOUDFRONT_DOMAIN}/health | jq .
# Expected: {"status": "healthy", ...}

# Test 2: Chat endpoint
curl -sf -X POST https://${CLOUDFRONT_DOMAIN}/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Say hello in one sentence"}' | jq .response
# Expected: A short greeting message

# Test 3: Rate limit header present
curl -I https://${CLOUDFRONT_DOMAIN}/chat \
  -X POST -H "Content-Type: application/json" \
  -d '{"message": "test"}' | grep -i x-ratelimit
# Expected: x-ratelimit-remaining header present

# Test 4: Invalid input rejected
curl -sf -X POST https://${CLOUDFRONT_DOMAIN}/chat \
  -H "Content-Type: application/json" \
  -d '{"notmessage": "test"}' 
# Expected: 400 status code

# Test 5: CORS correctly set
curl -I https://${CLOUDFRONT_DOMAIN}/chat \
  -X OPTIONS \
  -H "Origin: https://malicious.com"
# Expected: No Access-Control-Allow-Origin header (or different origin)
```

### Step 4 — Verify CloudWatch Metrics (5 minutes post-deploy)

Check:
- Lambda error rate: should be < 1%
- Lambda P99 duration: should be < 5000ms
- No WAF alarms triggered
- No DynamoDB throttle alarms

### Step 5 — Confirm Deployment Success

```
□ All smoke tests pass
□ CloudWatch metrics healthy
□ No alarms triggered
□ Frontend loads correctly in browser
□ End-to-end chat test works in browser
□ Post success to Slack #deployments
```

---

## Rollback Steps

If any smoke test fails or alarms fire within 30 minutes of deployment:

### Lambda Rollback (< 2 minutes)

```bash
# List Lambda versions
aws lambda list-versions-by-function \
  --function-name nakoba-chatbot-prod \
  --query 'Versions[-2].Version' \
  --output text

# Roll back
PREV_VERSION=[number from above]
aws lambda update-alias \
  --function-name nakoba-chatbot-prod \
  --name LIVE \
  --function-version ${PREV_VERSION}

echo "Lambda rolled back to version ${PREV_VERSION}"
```

### Frontend Rollback (< 2 minutes)

```bash
# S3 versioning is enabled — restore previous version
aws s3api list-object-versions \
  --bucket nakoba-frontend-prod \
  --prefix index.html \
  --query 'Versions[?IsLatest==`false`].[VersionId,LastModified]' \
  --output table

# Copy the previous version
PREV_VERSION_ID=[version id from above]
aws s3api copy-object \
  --copy-source "nakoba-frontend-prod/index.html?versionId=${PREV_VERSION_ID}" \
  --bucket nakoba-frontend-prod \
  --key index.html

# Invalidate CloudFront cache
DIST_ID=$(terraform output -raw cloudfront_distribution_id -chdir=terraform)
aws cloudfront create-invalidation \
  --distribution-id ${DIST_ID} \
  --paths "/index.html"

echo "Frontend rolled back"
```

### Terraform Infrastructure Rollback (< 10 minutes)

```bash
# Download previous state from S3
aws s3 cp \
  s3://nakoba-terraform-state/nakoba-chatbot/prod/terraform.tfstate.backup \
  terraform/terraform.tfstate.rollback

# Review what would change
cd terraform
terraform show terraform.tfstate.rollback

# Apply rollback (requires careful review)
# ONLY if Lambda + frontend rollbacks are insufficient
terraform apply -var-file="environments/prod.tfvars" \
  -state=terraform.tfstate.rollback
```

---

## Deployment Approval Matrix

| Change Type | Required Approvers | Test Required |
|------------|-------------------|--------------|
| Lambda code change | 1 | Staging smoke tests |
| Frontend update | 1 | Staging visual review |
| Terraform infrastructure change | 2 | Full staging run |
| WAF rule change | 2 | Staging traffic validation |
| IAM policy change | 2 + security review | Full staging run |
| Responsible AI guardrails | 1 + AI governance | Adversarial test suite |

---

## Change Freeze Periods

Production deployments are **prohibited** during:
- Friday 5pm → Monday 9am (weekend freeze)
- 24 hours before major holidays
- During active incidents (P0/P1)

Exception process: Engineering lead approval required for emergency patches during freeze.

---

## Release Tagging

After every successful production deployment:

```bash
# Create a semantic version tag
git tag -a v2.x.y -m "Production release v2.x.y — [brief description]"
git push origin v2.x.y

# GitHub Release created automatically by cd-prod.yml workflow
```

Version format: `v[major].[minor].[patch]`
- **Major:** Breaking API or architectural change
- **Minor:** New feature (backward-compatible)
- **Patch:** Bug fix or security update
