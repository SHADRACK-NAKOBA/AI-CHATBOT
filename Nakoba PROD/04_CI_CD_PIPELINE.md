# CI/CD Pipeline Documentation

## Pipeline Overview

```
Developer Push
      │
      ▼
┌─────────────────────────────────────────────┐
│           CI Pipeline (ci.yml)              │
│  Triggers on: every push + PR               │
│                                             │
│  1. Checkout + Setup Node.js 20             │
│  2. npm install                             │
│  3. npm audit (fail on high severity)       │
│  4. npm test (unit tests)                  │
│  5. Snyk vulnerability scan                 │
│  6. Checkov IaC scan (Terraform files)      │
│  7. Lint: terraform fmt -check              │
│  8. terraform validate                      │
└──────────────────┬──────────────────────────┘
                   │ All checks pass
                   ▼
         ┌─────────────────────────────────────┐
         │   Push to main branch?              │
         └──────────┬──────────────────────────┘
                    │ Yes
                    ▼
         ┌─────────────────────────────────────┐
         │   CD Staging (cd-staging.yml)       │
         │                                     │
         │  1. Deploy Lambda to staging        │
         │  2. Apply Terraform staging         │
         │  3. Deploy frontend to staging S3   │
         │  4. Smoke test staging endpoint     │
         │  5. Notify: Slack / email           │
         └──────────┬──────────────────────────┘
                    │ Staging healthy
                    ▼
         ┌─────────────────────────────────────┐
         │   Manual Approval Required          │
         │   (GitHub Environment Protection)   │
         │   2 required reviewers              │
         └──────────┬──────────────────────────┘
                    │ Approved
                    ▼
         ┌─────────────────────────────────────┐
         │   CD Production (cd-prod.yml)       │
         │                                     │
         │  1. Deploy Lambda to prod           │
         │  2. Apply Terraform prod            │
         │  3. Deploy frontend to prod S3      │
         │  4. Invalidate CloudFront cache     │
         │  5. Smoke test prod endpoint        │
         │  6. Tag release in GitHub           │
         └─────────────────────────────────────┘
```

---

## CI Pipeline Gates

### Gate 1: Dependency Security (`npm audit`)
```yaml
- run: npm audit --audit-level=high
```
- Fails build if any **high** or **critical** CVE is found in dependencies
- Action: Update or patch affected package before merge

### Gate 2: Unit Tests (`npm test`)
```yaml
- run: npm test
```
- All unit tests must pass
- Test coverage report uploaded as artifact

### Gate 3: Snyk Scan
```yaml
- uses: snyk/actions/node@master
  with:
    args: --severity-threshold=high
```
- Catches CVEs that `npm audit` may miss
- Requires `SNYK_TOKEN` secret

### Gate 4: IaC Security (Checkov)
```yaml
- uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
    soft_fail: false
```
- Catches: public S3 buckets, unencrypted resources, missing logging, overly permissive IAM
- All `HIGH` findings block the pipeline

### Gate 5: Terraform Validate
```yaml
- run: |
    cd terraform
    terraform init -backend=false
    terraform validate
    terraform fmt -check
```
- Syntax errors and formatting issues block merge

---

## Branch Strategy

```
main ─────────────────────────────────────────────────────────
  │         ↑ PR + review required
  │    feature/my-change
  │    bugfix/fix-cors
  │    security/update-deps
  │
  └── Auto-deploys to staging on merge
  └── Manual approval deploys to prod
```

- **Direct pushes to `main` are blocked** (enforce via GitHub branch protection)
- Required reviews: 1 for staging, 2 for production
- Status checks must pass before merge

---

## Deployment Environments (GitHub Environments)

| Environment | Protection Rules | Deployment URL |
|------------|-----------------|----------------|
| `staging` | No approvals, auto-deploy | staging CloudFront domain |
| `production` | 2 required approvers, 5 min wait | prod CloudFront domain |

Configure in: GitHub → Settings → Environments

---

## Pipeline Secrets Required

| Secret | Used In | Description |
|--------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | cd-staging, cd-prod | Terraform operator key |
| `AWS_SECRET_ACCESS_KEY` | cd-staging, cd-prod | Terraform operator secret |
| `AWS_REGION` | All | `us-east-1` |
| `ANTHROPIC_API_KEY` | ci (test only) | For running lambda/test.js in CI |
| `SNYK_TOKEN` | ci | Snyk vulnerability scanning |
| `SLACK_WEBHOOK_URL` | cd-prod | Deployment notification |

---

## Rollback Procedure

### Automatic Rollback (Lambda)
Lambda supports traffic shifting and rollback via aliases:
```bash
# Roll back to previous Lambda version
aws lambda update-alias \
  --function-name nakoba-chatbot-prod \
  --name LIVE \
  --function-version $PREVIOUS_VERSION
```

### Terraform Rollback
```bash
# Restore previous Terraform state
aws s3 cp \
  s3://nakoba-terraform-state/nakoba-chatbot/prod/terraform.tfstate.backup \
  terraform.tfstate

terraform apply -var-file="environments/prod.tfvars"
```

### Frontend Rollback
```bash
# S3 versioning enables instant rollback
aws s3api list-object-versions --bucket nakoba-frontend-prod --prefix index.html
aws s3api restore-object --bucket nakoba-frontend-prod \
  --key index.html --version-id [PREVIOUS_VERSION_ID]
```

---

## Notification Policy

| Event | Channel | Condition |
|-------|---------|-----------|
| CI failure | GitHub PR comment | On any gate failure |
| Staging deploy success | (logged) | After smoke test passes |
| Production deploy | Slack #deployments | Always |
| Production deploy failure | Slack #incidents + email | On failure |
| Security vulnerability found | GitHub Security tab | Snyk/npm audit finding |
