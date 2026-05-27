# Security & Governance Framework

## Security Principles

This system is built on three foundational security principles:

1. **Defense in Depth** — Multiple independent security layers; no single point of failure
2. **Least Privilege** — Every IAM role and policy grants only the minimum required permissions
3. **Zero Trust** — No implicit trust; all requests validated at every layer

---

## Security Controls Matrix

| Layer | Control | Implementation | Severity if Bypassed |
|-------|---------|----------------|---------------------|
| Network | Rate limiting | AWS WAF: 2000 req/5min per IP | High |
| Network | OWASP rules | AWS WAF Managed Core Rule Set | Critical |
| Network | SQLi/XSS | AWS WAF rule groups | Critical |
| Network | Bot control | AWS WAF Bot Control | Medium |
| Transport | HTTPS enforcement | CloudFront redirect HTTP→HTTPS | Critical |
| Transport | TLS version | TLS 1.2 minimum enforced | High |
| API | CORS | Restricted to CloudFront domain | High |
| Application | Input validation | Lambda: size, encoding, schema | High |
| Application | Rate limiting | DynamoDB: 100 req/min per IP | High |
| Application | Content moderation | Lambda: harmful pattern matching | Critical |
| Application | PII protection | Lambda: detect & redact | High |
| Application | Prompt injection | Lambda: system prompt protection | Critical |
| Data | Encryption at rest | S3 SSE-AES256, DynamoDB SSE | High |
| Data | Secrets management | AWS Secrets Manager (not env vars) | Critical |
| Identity | IAM least privilege | Separate role per service | High |
| Audit | Request logging | CloudWatch structured logs | High |
| Audit | Infrastructure changes | AWS CloudTrail | High |
| Compliance | Vulnerability scanning | npm audit + Snyk in CI | Medium |
| Compliance | IaC scanning | Checkov in CI | Medium |

---

## IAM Architecture (Least Privilege)

### Lambda Execution Role — `nakoba-chatbot-lambda-role`

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/nakoba-chatbot-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/nakoba-rate-limits-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:nakoba/anthropic-api-key-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ],
      "Resource": "*"
    }
  ]
}
```

### What the Lambda Role CANNOT Do
- Read or write S3 (not needed)
- Create or modify IAM roles
- Access other DynamoDB tables
- Access secrets outside its path prefix
- Deploy or update other Lambda functions
- Modify API Gateway or CloudFront

---

## Secrets Management

### ANTHROPIC_API_KEY — Storage Protocol

| ❌ PROHIBITED | ✅ REQUIRED |
|--------------|------------|
| Hardcoded in source code | AWS Secrets Manager |
| In .env files committed to git | Retrieved at Lambda runtime |
| In Lambda environment variables (plaintext) | Cached in memory (not re-fetched per request) |
| In CI/CD logs | GitHub Actions secret → Secrets Manager |

### Secret Rotation Policy
- Rotation enabled: Every 90 days
- Notification: CloudWatch alarm if rotation fails
- Emergency rotation: Runbook in [07_INCIDENT_RESPONSE.md](07_INCIDENT_RESPONSE.md)

---

## WAF Rule Groups (in priority order)

| Priority | Rule Group | Blocks |
|---------|-----------|--------|
| 10 | AWSManagedRulesCommonRuleSet | Common web exploits |
| 20 | AWSManagedRulesKnownBadInputsRuleSet | Log4Shell, Spring4Shell, SSRF |
| 30 | AWSManagedRulesSQLiRuleSet | SQL injection |
| 40 | AWSManagedRulesAmazonIpReputationList | Known bad IPs, botnets |
| 50 | Custom: Rate limit rule | 2000 req per 5 min per IP → 429 |

---

## Content Security Policy (Frontend)

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'unsafe-inline';
  style-src 'self' 'unsafe-inline';
  connect-src 'self' https://*.execute-api.us-east-1.amazonaws.com https://*.cloudfront.net;
  img-src 'self' data:;
  frame-ancestors 'none';
  form-action 'self';
  upgrade-insecure-requests;
```

Additional security headers set in CloudFront response headers policy:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`

---

## Data Classification

| Data Type | Classification | Handling |
|-----------|---------------|---------|
| User chat messages | Confidential | Logged (audit only), not stored persistently |
| Claude responses | Internal | Logged (audit only), not stored persistently |
| API keys | Secret | Secrets Manager, never logged |
| IP addresses | PII | Hashed in audit logs, TTL 30 days |
| Request metadata | Internal | CloudWatch Logs, retained 90 days |
| Terraform state | Sensitive | S3 + DynamoDB state locking, encryption required |

---

## CORS Policy

| Environment | Allowed Origin |
|------------|---------------|
| dev | `http://localhost:3000` |
| staging | `https://staging.d[id].cloudfront.net` |
| prod | `https://d[id].cloudfront.net` (specific domain) |

The Lambda function reads `ALLOWED_ORIGIN` from environment and validates the `Origin` header against it. Wildcard `*` is **never** used in production.

---

## Audit Logging Standard

Every API request produces a structured JSON log entry:

```json
{
  "timestamp": "2026-05-27T12:34:56.789Z",
  "requestId": "abc-123-def-456",
  "clientIp": "sha256:a1b2c3...",
  "event": "chat_request",
  "outcome": "success",
  "inputLength": 142,
  "outputLength": 387,
  "model": "claude-sonnet-4-20250514",
  "tokensUsed": {
    "input": 318,
    "output": 97
  },
  "responsibleAI": {
    "piiDetected": false,
    "harmfulContentBlocked": false,
    "promptInjectionAttempt": false
  },
  "durationMs": 1243,
  "environment": "prod"
}
```

**Retention:** CloudWatch Logs retained for 90 days. Exported to S3 Glacier for 7 years (compliance requirement).

---

## Governance — Tagging Strategy

All AWS resources are tagged with:

```
Project         = nakoba-ai-chatbot
Environment     = dev | staging | prod
Owner           = shadrack.n159@gmail.com
CostCenter      = engineering
DataClass       = confidential
ManagedBy       = terraform
CreatedDate     = 2026-05-27
```

Tags enable:
- Cost allocation by environment
- Automated backup policies
- Security scanning scope
- Resource lifecycle automation (dev resources auto-terminate after 7 days)

---

## Security Review Cadence

| Review Type | Frequency | Owner |
|------------|-----------|-------|
| Dependency vulnerability scan | Every CI run | GitHub Actions |
| IaC security scan (Checkov) | Every CI run | GitHub Actions |
| WAF log review | Weekly | Platform team |
| IAM access review | Quarterly | Security lead |
| Penetration test | Annual | External vendor |
| Responsible AI audit | Quarterly | AI governance team |
