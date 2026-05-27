# Nakoba AI Chatbot — Enterprise Production Platform

**Owner:** Prince Nakoba | **Contact:** shadrack.n159@gmail.com  
**Version:** 2.0.0-enterprise | **License:** MIT

A secure, governed, and responsible AI chatbot platform built on AWS serverless infrastructure with Anthropic Claude as the AI backend.

---

## Architecture

```
Users → CloudFront (CDN + HTTPS) → WAF → API Gateway → Lambda → Claude API
                                      ↓
                              S3 (Frontend) │ DynamoDB (Rate Limits) │ Secrets Manager │ CloudWatch
```

Full architecture diagram: [Nakoba PROD/01_ARCHITECTURE.md](Nakoba%20PROD/01_ARCHITECTURE.md)

---

## Repository Structure

```
├── ai-chatbot/                   # Application code
│   ├── frontend/index.html       # Chatbot UI (hardened with CSP)
│   ├── lambda/index.js           # Lambda handler (enterprise v2)
│   ├── lambda/middleware/        # Security middleware chain
│   │   ├── rateLimit.js          # DynamoDB-backed rate limiting
│   │   ├── inputValidation.js    # Input sanitization & size limits
│   │   ├── responsibleAI.js      # Content moderation & PII redaction
│   │   └── auditLogger.js        # Structured CloudWatch audit logging
│   └── infrastructure/           # Legacy shell scripts (superseded by Terraform)
│
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Provider & backend config
│   ├── lambda.tf                 # Lambda function
│   ├── api_gateway.tf            # HTTP API
│   ├── cloudfront.tf             # CDN + security headers
│   ├── waf.tf                    # WAF with managed rule groups
│   ├── dynamodb.tf               # Rate limit table
│   ├── s3.tf                     # Frontend hosting (private, OAC)
│   ├── iam.tf                    # Least-privilege IAM roles
│   ├── cloudwatch.tf             # Alarms, dashboards, budgets
│   └── environments/             # Per-environment variable files
│       ├── dev.tfvars
│       ├── staging.tfvars
│       └── prod.tfvars
│
├── .github/workflows/            # CI/CD pipelines
│   ├── ci.yml                    # Tests + security scanning (every push)
│   ├── cd-staging.yml            # Auto-deploy to staging on main merge
│   └── cd-prod.yml               # Manual-approval production deploy
│
└── Nakoba PROD/                  # Enterprise documentation
    ├── 00_PROJECT_OVERVIEW.md    # What was built and why
    ├── 01_ARCHITECTURE.md        # System architecture diagrams
    ├── 02_SECURITY_GOVERNANCE.md # Security controls matrix
    ├── 03_INFRASTRUCTURE_SETUP.md # How to provision infrastructure
    ├── 04_CI_CD_PIPELINE.md      # Pipeline documentation
    ├── 05_RESPONSIBLE_AI.md      # Responsible AI policy
    ├── 06_MONITORING_OBSERVABILITY.md # Dashboards and alerting
    ├── 07_INCIDENT_RESPONSE.md   # Incident playbooks
    ├── 08_COST_MANAGEMENT.md     # Cost controls and optimization
    └── 09_DEPLOYMENT_RUNBOOK.md  # Step-by-step production deployment
```

---

## Quick Start

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5
- Node.js >= 20

### 1. Store the Anthropic API Key
```bash
aws secretsmanager create-secret \
  --name "nakoba/anthropic-api-key" \
  --secret-string '{"api_key":"sk-ant-YOUR_KEY"}'
```

### 2. Set up Terraform backend (once)
See [Nakoba PROD/03_INFRASTRUCTURE_SETUP.md](Nakoba%20PROD/03_INFRASTRUCTURE_SETUP.md) — Step 2.

### 3. Deploy
```bash
cd terraform
terraform init -backend-config="..." 
terraform apply -var-file="environments/dev.tfvars"
```

### 4. Open the app
```bash
terraform output cloudfront_domain
# Open the URL in your browser
```

Full deployment guide: [Nakoba PROD/09_DEPLOYMENT_RUNBOOK.md](Nakoba%20PROD/09_DEPLOYMENT_RUNBOOK.md)

---

## Security Highlights

| Control | Implementation |
|---------|---------------|
| WAF | AWS WAF v2 with OWASP, SQLi, IP reputation rules |
| HTTPS | CloudFront enforces TLS 1.2+, redirects HTTP |
| Rate limiting | WAF (2000/5min) + Lambda middleware (100/min) |
| Secrets | AWS Secrets Manager (never in env vars or code) |
| IAM | Least-privilege per-service roles |
| PII | Auto-detected and redacted before reaching AI |
| Audit | Every request logged to CloudWatch |
| CSP | Content-Security-Policy meta tag on frontend |

Full security policy: [Nakoba PROD/02_SECURITY_GOVERNANCE.md](Nakoba%20PROD/02_SECURITY_GOVERNANCE.md)

---

## Responsible AI

- Harmful content patterns blocked before reaching Claude
- PII automatically redacted from messages
- Prompt injection attempts sanitized
- All AI interactions fully audited
- System prompt protected from user override
- Users informed they're talking to an AI

Policy: [Nakoba PROD/05_RESPONSIBLE_AI.md](Nakoba%20PROD/05_RESPONSIBLE_AI.md)

---

## CI/CD

| Pipeline | Trigger | What it does |
|---------|---------|-------------|
| CI | Every push | npm audit, unit tests, Snyk, Checkov, tf validate |
| CD Staging | Merge to main | Deploy to staging, smoke tests |
| CD Production | Manual approval | Deploy to prod, tag release |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | HTML/CSS/Vanilla JS (zero framework) |
| CDN | AWS CloudFront |
| Security | AWS WAF v2 |
| API | AWS API Gateway HTTP |
| Compute | AWS Lambda (Node.js 20.x) |
| AI Model | Anthropic Claude Sonnet 4 |
| Secrets | AWS Secrets Manager |
| Rate Limiting | DynamoDB (TTL-based) |
| IaC | Terraform |
| CI/CD | GitHub Actions |
