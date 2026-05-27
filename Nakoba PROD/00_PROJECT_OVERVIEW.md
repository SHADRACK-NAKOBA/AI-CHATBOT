# Nakoba PROD — Enterprise AI Chatbot Platform
## Project Overview

**Project Name:** Nakoba AI Chatbot — Enterprise Production System  
**Owner:** Prince Nakoba (SHADRACK-NAKOBA)  
**Repository:** https://github.com/SHADRACK-NAKOBA/CYBERSEC-ML-PLATFORM  
**Classification:** Production — Internal Use  
**Date:** 2026-05-27  
**Version:** 2.0.0-enterprise

---

## What Was Built

This enterprise production environment transforms the base AI chatbot into a secure, governed, scalable, and responsible AI system suitable for production deployment. The following enhancements were made across six layers:

| Layer | What Was Built |
|-------|----------------|
| **Security** | WAF, rate limiting, input validation, CSP headers, Secrets Manager, least-privilege IAM |
| **Infrastructure** | Terraform IaC for all AWS resources, multi-environment (dev/staging/prod), CloudFront CDN |
| **Responsible AI** | Content moderation guardrails, PII detection, harmful prompt blocking, audit trail |
| **CI/CD** | GitHub Actions: automated testing, security scanning, staged deployments |
| **Observability** | CloudWatch dashboards, alarms, structured audit logging, cost budgets |
| **Governance** | Tagging strategy, compliance documentation, incident response runbook |

---

## Step-by-Step Build Summary

### Step 1 — Architecture Design
**File:** [01_ARCHITECTURE.md](01_ARCHITECTURE.md)
- Designed a three-tier serverless architecture with CDN layer
- Separated compute (Lambda), API (API Gateway), CDN (CloudFront), and data (DynamoDB) tiers
- Added WAF as the security perimeter

### Step 2 — Security & Governance Framework
**File:** [02_SECURITY_GOVERNANCE.md](02_SECURITY_GOVERNANCE.md)
- Defined IAM roles using least-privilege principle
- Configured AWS WAF with managed rule groups (common threats, SQL injection, XSS, rate limits)
- Moved ANTHROPIC_API_KEY to AWS Secrets Manager (no secrets in environment variables)
- Added CORS hardening with per-environment allowed origins
- Enabled CloudTrail audit logging for all API calls

### Step 3 — Infrastructure as Code (Terraform)
**Files:** [../terraform/](../terraform/)
- Wrote complete Terraform modules for all AWS resources
- Created three environment configurations: dev, staging, prod
- Resources: Lambda, API Gateway (HTTP), CloudFront, S3, DynamoDB, Secrets Manager, WAF, CloudWatch, IAM, Budgets

### Step 4 — Responsible AI Layer
**File:** [05_RESPONSIBLE_AI.md](05_RESPONSIBLE_AI.md)
- Implemented prompt injection detection
- Added harmful content category blocking (violence, CSAM, jailbreak attempts)
- Built PII detection and redaction (emails, phone numbers, SSNs, credit cards)
- Created immutable audit log of all AI interactions in CloudWatch Logs
- Added system prompt integrity check (prevents override)

### Step 5 — Enterprise Lambda Middleware
**Files:** [../ai-chatbot/lambda/middleware/](../ai-chatbot/lambda/middleware/)
- `rateLimit.js` — DynamoDB-backed sliding window rate limiter (100 req/min per IP)
- `inputValidation.js` — Input sanitization, size limits, encoding validation
- `responsibleAI.js` — Content moderation, PII detection, harmful pattern matching
- `auditLogger.js` — Structured JSON audit log to CloudWatch with request correlation

### Step 6 — CI/CD Pipelines
**Files:** [../.github/workflows/](../.github/workflows/)
- `ci.yml` — Lint, unit tests, npm audit, Checkov IaC scanning, Snyk vulnerability scan
- `cd-staging.yml` — Auto-deploys to staging on push to `main`
- `cd-prod.yml` — Production deploy requires manual approval + passing staging

### Step 7 — Monitoring & Observability
**File:** [06_MONITORING_OBSERVABILITY.md](06_MONITORING_OBSERVABILITY.md)
- CloudWatch dashboard with 8 key metrics
- Alarms: Lambda errors >1%, P99 latency >5s, WAF blocked requests spike
- AWS Budgets: $50/month alert for dev, $200/month for prod
- Structured log format with correlation IDs for request tracing

### Step 8 — Frontend Security Hardening
**File:** [../ai-chatbot/frontend/index.html](../ai-chatbot/frontend/index.html)
- Added Content-Security-Policy meta tag
- Added API key header support (X-API-Key)
- Added request deduplication to prevent double-sends
- Implemented exponential backoff retry logic

### Step 9 — Documentation & Runbook
**Files:** [Nakoba PROD/](.)
- Architecture diagrams
- Security governance policy
- Deployment runbook (step-by-step production deployment)
- Incident response playbook
- Cost management guide
- Responsible AI policy

---

## Quick Navigation

| Document | Purpose |
|----------|---------|
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | System architecture and data flow |
| [02_SECURITY_GOVERNANCE.md](02_SECURITY_GOVERNANCE.md) | Security controls and governance |
| [03_INFRASTRUCTURE_SETUP.md](03_INFRASTRUCTURE_SETUP.md) | How to provision AWS infrastructure |
| [04_CI_CD_PIPELINE.md](04_CI_CD_PIPELINE.md) | CI/CD pipeline documentation |
| [05_RESPONSIBLE_AI.md](05_RESPONSIBLE_AI.md) | Responsible AI policy and guardrails |
| [06_MONITORING_OBSERVABILITY.md](06_MONITORING_OBSERVABILITY.md) | Monitoring, alerting, dashboards |
| [07_INCIDENT_RESPONSE.md](07_INCIDENT_RESPONSE.md) | Incident response playbook |
| [08_COST_MANAGEMENT.md](08_COST_MANAGEMENT.md) | Cost controls and optimization |
| [09_DEPLOYMENT_RUNBOOK.md](09_DEPLOYMENT_RUNBOOK.md) | Step-by-step production deployment |

---

## Technology Stack

| Component | Technology | Justification |
|-----------|-----------|---------------|
| Frontend | HTML/CSS/Vanilla JS | Zero dependency, fast, CDN-cacheable |
| CDN | AWS CloudFront | Global edge, HTTPS enforced, WAF integration |
| API | AWS API Gateway HTTP | Low latency, auto-scaling, IAM-ready |
| Security | AWS WAF v2 | Managed threat rules, rate limiting |
| Compute | AWS Lambda (Node.js 20.x) | Serverless, scales to zero, no idle cost |
| AI Model | Anthropic Claude Sonnet 4 | State-of-the-art, safety-trained |
| Secrets | AWS Secrets Manager | Encrypted, rotatable, no secrets in code |
| Rate Limiting | DynamoDB (TTL) | Low-latency, serverless, auto-expire |
| Logging | CloudWatch Logs + Insights | Centralized, queryable, archivable |
| IaC | Terraform | Version-controlled, repeatable infra |
| CI/CD | GitHub Actions | Native GitHub, free for public repos |
| Package Security | npm audit + Snyk | Automated CVE detection |
| IaC Security | Checkov | CIS benchmark scanning for Terraform |

---

## Compliance Posture

| Control | Status | Implementation |
|---------|--------|----------------|
| Encryption at rest | Enabled | S3 SSE-AES256, DynamoDB SSE |
| Encryption in transit | Enforced | HTTPS/TLS 1.2+ via CloudFront |
| Access control | Role-based | IAM least privilege |
| Audit logging | Complete | CloudTrail + CloudWatch structured logs |
| Secrets management | Centralized | AWS Secrets Manager |
| Vulnerability scanning | Automated | npm audit + Snyk + Checkov in CI |
| Rate limiting | Layer 2+7 | WAF + Lambda middleware |
| Data residency | Configurable | Terraform variable: aws_region |
| PII protection | Automated | Lambda middleware redaction |
| Incident response | Documented | [07_INCIDENT_RESPONSE.md](07_INCIDENT_RESPONSE.md) |
