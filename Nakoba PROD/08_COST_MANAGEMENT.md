# Cost Management Guide

## Cost Architecture

All infrastructure uses serverless and pay-per-use services to minimize idle costs:

| Service | Billing Model | Free Tier | Estimated Monthly (1K users/day) |
|---------|--------------|-----------|----------------------------------|
| AWS Lambda | Per invocation + duration | 1M invocations/month | ~$0.50 |
| API Gateway (HTTP) | Per API call | 1M calls/month | ~$1.00 |
| CloudFront | Per request + data transfer | 10M requests/month | ~$2.00 |
| S3 (static hosting) | Per GB + requests | 5GB storage | ~$0.10 |
| DynamoDB (rate limits) | Per request + storage | 25GB + 25 RCU/WCU | ~$0.50 |
| AWS WAF | Per rule + request | None | ~$6.00 |
| Secrets Manager | Per secret + API calls | None | ~$0.40 |
| CloudWatch (logs) | Per GB ingested | 5GB/month | ~$1.00 |
| **Anthropic Claude API** | Per token | None | **Dominant cost** |
| **TOTAL (infra only)** | | | **~$12/month** |

> **Note:** Anthropic API costs dominate at scale. Estimate: ~$0.003 per 1K input tokens + $0.015 per 1K output tokens for Claude Sonnet.

---

## Cost Controls Implemented

### Control 1: Token Limits

```javascript
// lambda/index.js — Max output tokens per response
max_tokens: 1024  // ~$0.015 max per response
```

Prevents runaway model responses from inflating costs.

### Control 2: Conversation History Limit

```javascript
// frontend/index.html — Max history size
const MAX_HISTORY = 20;  // ~40 turns of context max
```

Limits input token growth in multi-turn conversations.

### Control 3: Input Size Limit

```javascript
// lambda/middleware/inputValidation.js
const MAX_INPUT_BYTES = 10 * 1024;  // 10KB max per message
```

Prevents large text dumps from inflating input token costs.

### Control 4: Rate Limiting

```javascript
// lambda/middleware/rateLimit.js
const REQUESTS_PER_MINUTE = 100;  // per IP
```

Prevents abuse from driving up costs via automated requests.

### Control 5: WAF Rate Limiting

```
WAF Rule: 2000 requests per 5 minutes per IP
```

Network-level protection before Lambda is even invoked (no Lambda cost for blocked requests).

### Control 6: AWS Budgets

```hcl
# terraform/cloudwatch.tf
resource "aws_budgets_budget" "prod" {
  limit_amount = "200"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  notification {
    threshold = 80  # Alert at 80% ($160)
    threshold = 100 # Alert at 100% ($200)
  }
}
```

---

## Cost Optimization Strategies

### Immediate (Already Implemented)

- **HTTP API vs REST API:** 70% cost reduction vs API Gateway REST API
- **Serverless:** Zero cost at zero load (scales to zero automatically)
- **CloudFront caching:** Static assets cached at edge (no S3 origin hits)
- **DynamoDB TTL:** Rate limit records auto-expire (no manual cleanup cost)
- **Lambda ARM64:** Consider migrating to `arm64` architecture for ~20% cost reduction

### Future Optimizations (When Scale Warrants)

| Strategy | Savings | When to Apply |
|---------|---------|---------------|
| Lambda Provisioned Concurrency | Eliminate cold starts at fixed cost | >100K requests/day |
| DynamoDB Reserved Capacity | 70% cheaper than on-demand | >10M reads/month |
| CloudFront Reserved Capacity | Discounted data transfer | >10TB/month |
| Savings Plans (Compute) | Up to 66% off Lambda | >$50/month Lambda spend |
| Anthropic Batch API | 50% discount on tokens | Offline/async workloads |

---

## Cost Monitoring

### Monthly Cost Review Checklist

```
□ Review AWS Cost Explorer — any unexpected services?
□ Check Lambda invocation count vs previous month
□ Check Anthropic API usage dashboard
□ Review CloudFront bandwidth
□ Check DynamoDB read/write units consumed
□ Compare actual vs budgeted — update budget if legitimate growth
```

### Cost Anomaly Detection

AWS Cost Anomaly Detection is configured to alert when:
- Any single service exceeds 20% of its normal daily spend
- Total daily spend exceeds $10 (dev) or $30 (prod)

Alert → SNS → shadrack.n159@gmail.com

---

## Environment Cost Isolation

All resources are tagged with `Environment = dev | staging | prod`.

AWS Cost Explorer filter by tag enables per-environment cost reporting.

**Target monthly spend by environment:**

| Environment | Target | Hard Budget |
|------------|--------|------------|
| dev | $20 | $50 |
| staging | $40 | $100 |
| prod | $100 | $200 |

Dev resources that have been idle for 7 days are automatically flagged for review via CloudWatch scheduled event.
