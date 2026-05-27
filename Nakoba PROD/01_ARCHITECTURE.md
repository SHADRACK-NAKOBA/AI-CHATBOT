# Architecture — Enterprise AI Chatbot Platform

## System Architecture

```
                        ┌─────────────────────────────────────────────────────────────┐
                        │                    INTERNET / USERS                         │
                        └─────────────────────────────┬───────────────────────────────┘
                                                       │ HTTPS (TLS 1.2+)
                        ┌─────────────────────────────▼───────────────────────────────┐
                        │              AWS WAF v2 (Security Perimeter)                │
                        │  • Managed Core Rule Set (OWASP Top 10)                     │
                        │  • SQLi & XSS Protection                                    │
                        │  • Bot Control                                               │
                        │  • Rate Limit: 2000 req/5min per IP                         │
                        └─────────────────────────────┬───────────────────────────────┘
                                                       │
                        ┌─────────────────────────────▼───────────────────────────────┐
                        │             AWS CloudFront (CDN + HTTPS Termination)        │
                        │  • Global Edge Locations                                    │
                        │  • HTTPS Enforced (redirect HTTP→HTTPS)                    │
                        │  • TLS 1.2 minimum                                          │
                        │  • Geo-restriction (configurable)                           │
                        │  • Cache: Static assets (index.html, 1hr TTL)              │
                        └──────────┬──────────────────────────────┬───────────────────┘
                                   │                              │
                     ┌─────────────▼──────────┐    ┌─────────────▼──────────┐
                     │   S3 Bucket (Origin)   │    │ API Gateway HTTP API   │
                     │   • Static Frontend    │    │   • POST /chat         │
                     │   • SSE-AES256         │    │   • OPTIONS /chat      │
                     │   • No public access   │    │   • GET /health        │
                     │   • OAC restricted     │    │   • CORS restricted    │
                     └────────────────────────┘    └─────────────┬──────────┘
                                                                  │ IAM Auth
                                                   ┌─────────────▼──────────┐
                                                   │   AWS Lambda Function   │
                                                   │   Node.js 20.x          │
                                                   │                         │
                                                   │  ┌─────────────────┐   │
                                                   │  │ Rate Limiter    │   │
                                                   │  │ (DynamoDB TTL)  │   │
                                                   │  └────────┬────────┘   │
                                                   │           │            │
                                                   │  ┌────────▼────────┐   │
                                                   │  │ Input Validator │   │
                                                   │  │ (sanitize/size) │   │
                                                   │  └────────┬────────┘   │
                                                   │           │            │
                                                   │  ┌────────▼────────┐   │
                                                   │  │ Responsible AI  │   │
                                                   │  │ (PII/harm guard)│   │
                                                   │  └────────┬────────┘   │
                                                   │           │            │
                                                   │  ┌────────▼────────┐   │
                                                   │  │ Claude API Call │   │
                                                   │  │ (Anthropic SDK) │   │
                                                   │  └────────┬────────┘   │
                                                   │           │            │
                                                   │  ┌────────▼────────┐   │
                                                   │  │  Audit Logger   │   │
                                                   │  │ (CloudWatch)    │   │
                                                   │  └─────────────────┘   │
                                                   └──────────┬─────────────┘
                                                              │
                              ┌───────────────────────────────┼─────────────────────────┐
                              │                               │                         │
              ┌───────────────▼────────┐   ┌─────────────────▼────────┐  ┌─────────────▼────┐
              │     DynamoDB            │   │    Secrets Manager        │  │  CloudWatch Logs  │
              │  • Rate limit counters  │   │  • ANTHROPIC_API_KEY      │  │  • Request audit  │
              │  • TTL auto-expire      │   │  • Encrypted at rest      │  │  • Error tracking │
              │  • Encryption at rest   │   │  • Auto-rotation capable  │  │  • Metric filters │
              └────────────────────────┘   └──────────────────────────┘  └───────────────────┘
                                                                                    │
                                                                    ┌───────────────▼────────┐
                                                                    │  CloudWatch Dashboard   │
                                                                    │  & Alarms               │
                                                                    │  • P99 latency          │
                                                                    │  • Error rate           │
                                                                    │  • WAF blocks           │
                                                                    │  • Cost alerts          │
                                                                    └────────────────────────┘
```

---

## Data Flow

### Chat Request (Happy Path)

```
1. User types message in browser (index.html)
2. JavaScript POSTs to CloudFront /chat endpoint
3. WAF inspects request:
   - Check rate limit (2000 req/5min per IP)
   - Match against managed rule groups
   - If blocked → 403 returned to user
4. CloudFront forwards to API Gateway
5. API Gateway invokes Lambda function
6. Lambda Middleware Chain:
   a. rateLimit.js     → DynamoDB lookup: increment counter, check limit (100/min)
   b. inputValidation  → Validate JSON, size (<10KB), sanitize HTML entities
   c. responsibleAI    → Scan for PII, harmful patterns, prompt injection
   d. Claude API call  → Anthropic SDK with system prompt + conversation history
   e. auditLogger      → Write structured JSON log to CloudWatch
7. Lambda returns {response, tokens} to API Gateway
8. API Gateway returns to CloudFront → User
```

### Security Rejection Paths

```
Rate limit exceeded   → 429 Too Many Requests
WAF block             → 403 Forbidden
Input too large       → 400 Bad Request (max 10KB)
Harmful content       → 400 with safe error message (no leak of filter reason)
PII detected          → Message is sanitized before sending to Claude
Lambda error          → 500 (internal detail never exposed to client)
```

---

## Environment Architecture

| Environment | Purpose | AWS Account | Auto-Deploy | Approval Required |
|------------|---------|-------------|-------------|------------------|
| dev | Development testing | Shared | On PR merge to `dev` | No |
| staging | Pre-production validation | Shared | On merge to `main` | No |
| prod | Live production | Dedicated | Manual trigger | Yes (2 approvers) |

---

## Multi-Region Consideration

The default deployment is single-region (`us-east-1`). For disaster recovery:

- CloudFront operates globally by default
- DynamoDB Global Tables can be enabled for multi-region rate limiting
- Lambda can be deployed to a secondary region with Route53 failover
- S3 Cross-Region Replication for static assets

---

## Security Zones

```
Zone 0 — Public Internet
  └── Any IP, any user

Zone 1 — WAF Perimeter (AWS Shield Standard included)
  └── IP reputation lists, rate limiting, OWASP rules enforced

Zone 2 — CloudFront (TLS Termination)
  └── HTTPS enforced, geographic restrictions optional

Zone 3 — API Gateway
  └── CORS restricted to CloudFront domain only

Zone 4 — Lambda VPC (optional, currently disabled for cost)
  └── Can be placed in private subnet for DB connectivity

Zone 5 — AWS Internal Services
  └── DynamoDB, Secrets Manager accessed via VPC endpoints or IAM
```

---

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| IaC tool | Terraform | State management, team collaboration, wide ecosystem |
| CDN | CloudFront | WAF integration, OAC for S3, HTTPS enforcement |
| API type | HTTP API (not REST) | 70% cheaper, lower latency, sufficient features |
| Auth model | CORS + WAF | Stateless, no Cognito complexity for public chatbot |
| Rate limiting | DynamoDB TTL | Serverless, no Redis cost, auto-expire |
| Secret storage | Secrets Manager | Not SSM Parameter Store — rotation API, audit trail |
| Logging | CloudWatch structured JSON | Insights queries, metric filters, native Lambda |
| CI security | Checkov + npm audit | Free, catches IaC misconfig + dependency CVEs |
