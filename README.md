# Nakoba AI Chatbot — Enterprise Production Platform

**Owner:** Prince Nakoba | **Contact:** shadrack.n159@gmail.com  
**Version:** 2.0.0-enterprise | **License:** MIT

A secure, governed, and responsible AI chatbot platform built on AWS serverless infrastructure with Anthropic Claude as the AI backend.

---

## 🎓 Prince Hands-On Lab — Build this yourself

| # | Step | Time |
|---|---|---|
| 00 | [Project overview and architecture](docs/00-overview.md) | 10 min |
| 01 | [Prerequisites: AWS, Anthropic, GitHub accounts and tools](docs/01-prerequisites.md) | 30 min |
| 02 | [Clone the repo and set your email](docs/02-clone-and-configure.md) | 5 min |
| 03 | [Bootstrap: AWS login, state bucket, API key](docs/03-bootstrap.md) | 10 min |
| 04 | [Deploy with Terraform](docs/04-deploy.md) | 20 min |
| 05 | [Test: browser, curl, PII, guardrails, WAF, rate limit](docs/05-test.md) | 20 min |
| 06 | [Monitoring: logs, Logs Insights, alarms](docs/06-monitoring.md) | 15 min |
| 07 | [CI/CD with GitHub Actions (optional)](docs/07-ci-cd.md) | 30 min |
| 08 | [Make a change and roll back](docs/08-update-and-rollback.md) | 15 min |
| 09 | [**Clean up** ⚠️](docs/09-cleanup.md) | 15 min |
| 10 | [Troubleshooting](docs/10-troubleshooting.md) | — |
| 11 | [Share your work](docs/11-share-your-work.md) | — |

**Cost:** cents if you destroy the stack the same day (see [docs/00-overview.md](docs/00-overview.md#time-and-cost)).

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
│   ├── cloudwatch.tf             # Alarms, SNS alerts, budgets
│   └── environments/             # Per-environment variable files
│       ├── dev.tfvars
│       ├── staging.tfvars
│       └── prod.tfvars
│
├── scripts/                      # Student lab scripts (bootstrap, deploy, smoke-test, destroy)
├── docs/                         # Click-by-click student lab guide
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

> **Students:** follow the click-by-click lab in [`docs/`](docs/00-overview.md). The four commands below are the short version.

**Prerequisites:** AWS account + IAM user access keys, Anthropic API key with credits, Git (Git Bash on Windows), AWS CLI v2, Terraform ≥ 1.5, Node.js ≥ 22. See [docs/01-prerequisites.md](docs/01-prerequisites.md).

```bash
git clone https://github.com/SHADRACK-NAKOBA/AI-CHATBOT.git && cd AI-CHATBOT
# 1. Put YOUR email in terraform/environments/dev.tfvars (owner_email)
aws configure                      # 2. log in to AWS (region us-east-1)
./scripts/bootstrap.sh             # 3. state bucket + lock table + Anthropic key secret (once)
./scripts/deploy.sh dev            # 4. build Lambda + terraform apply (10-20 min)
./scripts/smoke-test.sh dev        #    6 automatic checks through CloudFront
./scripts/destroy.sh dev           #    delete everything when done (add --all to remove bootstrap too)
```

Full production runbook: [Nakoba PROD/09_DEPLOYMENT_RUNBOOK.md](Nakoba%20PROD/09_DEPLOYMENT_RUNBOOK.md)

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
| CI | Every push | npm audit, 15 offline unit tests, Snyk (if token set), Checkov, tf validate |
| CD Staging | Merge to main (when repo variable `ENABLE_CD=true`) | Deploy to staging, smoke tests |
| CD Production | Manual + approval (when `ENABLE_CD=true`) | Deploy to prod, tag release |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | HTML/CSS/Vanilla JS (zero framework) |
| CDN | AWS CloudFront |
| Security | AWS WAF v2 |
| API | AWS API Gateway HTTP |
| Compute | AWS Lambda (Node.js 24.x) |
| AI Model | Anthropic Claude Sonnet 5.5 (`claude-sonnet-5-5`, configurable via `anthropic_model`) |
| Secrets | AWS Secrets Manager |
| Rate Limiting | DynamoDB (TTL-based) |
| IaC | Terraform |
| CI/CD | GitHub Actions |

## Changelog — v2.1 (lab-ready)
- Model updated to `claude-sonnet-5-5` and made configurable (`claude-sonnet-4-20250514` was retired on 15 June 2026).
- Lambda runtime `nodejs20.x` → `nodejs24.x` (Node 20 is deprecated on Lambda).
- PII is now redacted in conversation **history** too, not only the latest message.
- Frontend calls `/chat` on the CloudFront domain, so all API traffic passes through the WAF.
- `terraform apply` uploads the frontend; `terraform destroy` works in dev/staging (versioned buckets emptied).
- CloudFront logging fixed (S3 ownership controls); origin request policy added for API Gateway.
- Reserved concurrency defaults to unreserved (new AWS accounts allow only 10).
- `owner_email` is required per environment instead of defaulting to one person's inbox.
- Checkov passes (skip comments moved inside resources); CI unit tests run offline; CD is opt-in via `ENABLE_CD`.
- Rate-limit salt precedence bug fixed; 15 offline unit tests added.
- Added `scripts/` and the `docs/` student lab; fixed runbook commands (`terraform -chdir`, bucket names, rollback).

