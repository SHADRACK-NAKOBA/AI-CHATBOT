# Incident Response Playbook

**Owner:** Prince Nakoba  
**Contact:** shadrack.n159@gmail.com  
**Last Updated:** 2026-05-27

---

## Severity Levels

| Severity | Definition | Response Time | Example |
|----------|-----------|---------------|---------|
| **P0 — Critical** | Service completely down or active security breach | 15 minutes | Lambda returning 500 for all requests, API key exposed |
| **P1 — High** | Major feature broken or significant security risk | 1 hour | WAF blocking all legitimate traffic, CSAM attempt detected |
| **P2 — Medium** | Degraded performance or potential policy violation | 4 hours | P99 latency >10s, unusual spike in harmful content blocks |
| **P3 — Low** | Minor issue, no user impact | 24 hours | Dependency CVE (no known exploit), cost overrun <20% |

---

## Incident Types and Playbooks

---

### INC-001: Service Down (Lambda 5xx for All Requests)

**Trigger:** CloudWatch alarm `nakoba-high-error-rate` fires (>5% errors)

**Step 1 — Diagnose**
```bash
# Check Lambda errors
aws logs tail /aws/lambda/nakoba-chatbot-prod --follow --format short

# Check if Lambda is being invoked
aws lambda get-function --function-name nakoba-chatbot-prod

# Check Anthropic API status
# → https://status.anthropic.com
```

**Step 2 — Identify Root Cause**

| Symptom | Cause | Fix |
|---------|-------|-----|
| `SecretNotFoundError` | Secrets Manager secret deleted | Re-create secret (Step 3 in setup guide) |
| `ThrottlingException` | Lambda concurrency limit | Request limit increase from AWS |
| `Task timed out` | Lambda timeout too short or Anthropic slow | Increase timeout in Terraform |
| `Module not found` | Bad Lambda deployment | Roll back to previous version |
| Anthropic API 5xx | Anthropic outage | Wait for recovery; no action needed |

**Step 3 — Rollback**
```bash
# Get list of Lambda versions
aws lambda list-versions-by-function --function-name nakoba-chatbot-prod

# Roll back to previous version
aws lambda update-alias \
  --function-name nakoba-chatbot-prod \
  --name LIVE \
  --function-version [PREVIOUS_VERSION]
```

**Step 4 — Confirm Recovery**
```bash
curl -X POST https://[CLOUDFRONT_DOMAIN]/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Health check"}'
```

---

### INC-002: API Key Exposure (ANTHROPIC_API_KEY Compromised)

**Trigger:** Key found in logs, GitHub, or reported by third party

**Severity: P0 — Immediate action required**

**Step 1 — Rotate Key Immediately (< 5 minutes)**
```bash
# 1. Go to console.anthropic.com → API Keys → Revoke the exposed key
# 2. Generate a new key
# 3. Update in Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id nakoba/anthropic-api-key \
  --secret-string '{"api_key":"sk-ant-NEW_KEY_HERE"}'

# 4. Lambda automatically picks up new key on next cold start
# 5. Force cold start by updating environment variable (any change triggers it)
aws lambda update-function-configuration \
  --function-name nakoba-chatbot-prod \
  --environment Variables={FORCE_REFRESH=true,ALLOWED_ORIGIN=https://example.cloudfront.net}
```

**Step 2 — Audit**
```bash
# Check CloudWatch for any abnormal usage (before rotation)
aws logs start-query \
  --log-group-name /aws/lambda/nakoba-chatbot-prod \
  --start-time $(date -d '24 hours ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, inputLength, outputLength | stats count() by bin(1h)'
```

**Step 3 — Review and Document**
- Where was the key exposed? (git commit, log, environment variable)
- Was it actually used by an unauthorized party? (check Anthropic usage dashboard)
- How did it leak? Fix the root cause.
- Document in incident log.

---

### INC-003: Harmful Content Bypass

**Trigger:** A user successfully elicits harmful output from Claude despite guardrails

**Severity: P1**

**Step 1 — Gather Evidence**
```bash
# Search CloudWatch for the request
aws logs start-query \
  --log-group-name /aws/lambda/nakoba-chatbot-prod \
  --query-string 'fields @timestamp, @message | filter requestId = "[REQUEST_ID]"'
```

**Step 2 — Analyze**
- What was the user input that bypassed filters?
- What harmful content was produced?
- Which guardrail should have caught it?

**Step 3 — Update Guardrails**
```javascript
// In lambda/middleware/responsibleAI.js
// Add new pattern to ABSOLUTE_BLOCK_PATTERNS
const ABSOLUTE_BLOCK_PATTERNS = [
  ...existing,
  /new_harmful_pattern/i,  // Added after INC-003
];
```

**Step 4 — Deploy and Verify**
- Create PR with new pattern
- CI must pass all tests
- Deploy to staging, verify block works
- Deploy to prod

**Step 5 — Report**
- If content could cause real-world harm, consider reporting to Anthropic: safety@anthropic.com

---

### INC-004: WAF Blocking Legitimate Users

**Trigger:** Users reporting 403 errors; confirmed not a rate limit issue

**Step 1 — Identify the Blocking Rule**
```bash
# Get WAF sampled requests
aws wafv2 get-sampled-requests \
  --web-acl-arn [WAF_ARN] \
  --rule-metric-name [RULE_NAME] \
  --scope CLOUDFRONT \
  --time-window StartTime=[START],EndTime=[END] \
  --max-items 100
```

**Step 2 — Assess Impact**
- Is this a specific user, IP range, or all users?
- Which WAF rule is triggering?

**Step 3 — Add Exclusion**
```bash
# Via Terraform: add rule exclusion in terraform/waf.tf
# Example: exclude a specific header from inspection
```

**Step 4 — Apply**
```bash
cd terraform
terraform plan -var-file="environments/prod.tfvars"
# Review: only WAF changes
terraform apply prod.plan
```

---

### INC-005: AWS Cost Anomaly

**Trigger:** AWS Budgets alert fires; charges exceed threshold

**Step 1 — Identify Source**
```bash
# Check Cost Explorer for the anomaly
# AWS Console → Cost Management → Cost Explorer → Service breakdown
```

**Step 2 — Common Causes**

| Cause | Fix |
|-------|-----|
| Lambda invocations spike | Check for loop/retry bug in frontend |
| DynamoDB scan (not point read) | Review DynamoDB access patterns in Lambda |
| CloudFront data transfer | Content being abused as free CDN |
| Anthropic API token usage | Check for very long conversations or large inputs |

**Step 3 — Contain**
```bash
# Temporarily reduce WAF rate limit to throttle traffic
# In terraform/waf.tf: reduce rate_based_rule limit from 2000 to 500
```

---

## Post-Incident Review Process

After every P0/P1 incident:

1. **Timeline reconstruction** — What happened, when, and in what order?
2. **Root cause analysis** — 5 Whys technique
3. **Impact assessment** — Users affected, duration, data exposure?
4. **Action items** — Specific, assignable, time-bound fixes
5. **Documentation update** — Update this runbook if a new scenario was encountered
6. **Share learnings** — Post-mortem shared with team

**Post-mortem template:**

```markdown
## Incident Post-Mortem: INC-[NUMBER]

**Date:** 
**Duration:**
**Severity:**
**Detected By:**

### Timeline
- HH:MM — Event
- HH:MM — Event

### Root Cause
[5 Whys analysis]

### Impact
[Users affected, duration, data involved]

### Resolution
[What fixed it]

### Action Items
| Action | Owner | Due Date |
|--------|-------|---------|
|        |       |         |

### Lessons Learned
```
