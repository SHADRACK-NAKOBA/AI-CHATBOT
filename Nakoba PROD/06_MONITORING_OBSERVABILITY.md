# Monitoring & Observability

## CloudWatch Dashboard: Nakoba AI Chatbot

The dashboard `nakoba-chatbot-prod` contains 8 widgets:

```
┌──────────────────────┬──────────────────────┬──────────────────────┐
│  Requests / min      │  Error Rate (%)       │  P99 Latency (ms)    │
│  [Line chart]        │  [Line chart]         │  [Line chart]        │
│  Target: <500/min    │  Target: <1%          │  Target: <5000ms     │
├──────────────────────┼──────────────────────┼──────────────────────┤
│  Lambda Duration     │  WAF Blocked Req      │  DynamoDB Throttles  │
│  P50/P95/P99         │  [Bar chart]          │  [Line chart]        │
│  [Line chart]        │  Alert: >100/5min     │  Alert: >10/min      │
├──────────────────────┴──────────────────────┴──────────────────────┤
│  Token Usage (input + output per hour)                              │
│  [Stacked area chart — for cost visibility]                         │
├─────────────────────────────────────────────────────────────────────┤
│  Responsible AI Events (blocked/flagged per hour)                   │
│  [Bar chart — separate bars for PII, harmful, injection]            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## CloudWatch Alarms

| Alarm Name | Metric | Threshold | Period | Action |
|------------|--------|-----------|--------|--------|
| `nakoba-high-error-rate` | Lambda errors / invocations | > 5% | 5 min | SNS → email |
| `nakoba-p99-latency` | Lambda P99 duration | > 5000ms | 5 min | SNS → email |
| `nakoba-waf-block-spike` | WAF blocked requests | > 100 in 5 min | 5 min | SNS → email |
| `nakoba-lambda-throttles` | Lambda throttles | > 10 | 1 min | SNS → email |
| `nakoba-dynamodb-throttle` | DynamoDB throttled requests | > 10 | 1 min | SNS → email |
| `nakoba-cost-alert` | EstimatedCharges | > $50 (dev), $200 (prod) | 24 hr | SNS → email |
| `nakoba-responsible-ai-block` | Custom metric: harmful_content_blocked | > 50 in 1 hr | 1 hr | SNS → email + Slack |
| `nakoba-secrets-rotation-fail` | Secrets Manager rotation failure | Any failure | 1 day | SNS → email |

---

## Log Insights Queries

### Query 1: Error Rate by Hour
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() as errors by bin(1h)
| sort @timestamp desc
```

### Query 2: Average Response Time
```
fields durationMs
| filter event = "chat_request" and outcome = "success"
| stats avg(durationMs) as avg_ms, pct(durationMs, 99) as p99_ms by bin(5m)
```

### Query 3: Responsible AI Events
```
fields @timestamp, responsibleAI.piiDetected, responsibleAI.harmfulContentBlocked, responsibleAI.promptInjectionAttempt
| filter responsibleAI.piiDetected = 1 or responsibleAI.harmfulContentBlocked = 1 or responsibleAI.promptInjectionAttempt = 1
| stats count() by bin(1h)
```

### Query 4: Token Usage (Cost Proxy)
```
fields tokensUsed.input, tokensUsed.output
| filter outcome = "success"
| stats sum(tokensUsed.input) as total_input, sum(tokensUsed.output) as total_output by bin(1h)
```

### Query 5: Top WAF Blocked IPs (Operational Use Only)
```
fields clientIp, outcome
| filter outcome = "waf_blocked"
| stats count() as blocks by clientIp
| sort blocks desc
| limit 20
```

---

## Metric Filters (CloudWatch Logs → Custom Metrics)

| Filter Name | Pattern | Metric Name | Namespace |
|------------|---------|-------------|-----------|
| `harmful-content` | `"harmfulContentBlocked\":true"` | `HarmfulContentBlocked` | `NakobaAI/Security` |
| `pii-detected` | `"piiDetected\":true"` | `PIIDetected` | `NakobaAI/Security` |
| `injection-attempt` | `"promptInjectionAttempt\":true"` | `PromptInjectionAttempt` | `NakobaAI/Security` |
| `rate-limited` | `"outcome\":\"rate_limited\""` | `RateLimitHits` | `NakobaAI/Traffic` |
| `chat-success` | `"event\":\"chat_request\".*\"outcome\":\"success\""` | `SuccessfulChats` | `NakobaAI/Traffic` |

---

## AWS Budgets

| Budget | Environment | Alert at | Alert at 80% |
|--------|------------|---------|-------------|
| `nakoba-dev-monthly` | dev | $50/month | $40 |
| `nakoba-staging-monthly` | staging | $100/month | $80 |
| `nakoba-prod-monthly` | prod | $200/month | $160 |

All budget alerts → SNS → shadrack.n159@gmail.com

---

## Health Check Endpoint

`GET /health` returns:

```json
{
  "status": "healthy",
  "timestamp": "2026-05-27T12:34:56.789Z",
  "version": "2.0.0",
  "environment": "prod",
  "checks": {
    "dynamodb": "ok",
    "secretsManager": "ok"
  }
}
```

CloudWatch Synthetic Canary pings `/health` every 5 minutes. If 2 consecutive failures → alarm → page on-call.

---

## X-Ray Distributed Tracing

AWS X-Ray is enabled on the Lambda function. Traces capture:
- Lambda cold start duration
- DynamoDB call latency (rate limit lookup)
- Secrets Manager call latency (first request only — cached after)
- Anthropic API call duration
- Total end-to-end latency

Access traces: AWS Console → X-Ray → Service Map

---

## On-Call Runbook

| Alert | Immediate Action |
|-------|-----------------|
| High error rate | Check Lambda logs, check Anthropic API status |
| High latency | Check for Lambda cold starts, DynamoDB latency |
| WAF block spike | Review WAF logs — legitimate spike or attack? |
| Cost alert | Check token usage — model response unexpectedly long? |
| Responsible AI spike | Review audit logs for patterns — update block list if needed |
| Secrets rotation failure | Manually rotate via AWS console, verify Lambda still works |
