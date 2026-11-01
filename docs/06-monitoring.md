# 06 · Monitoring and audit logs

[← Test](05-test.md) · [🏠 Lab home](../README.md) · [Next: CI/CD →](07-ci-cd.md)

Every request writes one structured JSON audit line to CloudWatch, without the message text and with the IP hashed.

## 1. Live logs from Git Bash
```bash
aws logs tail /aws/lambda/nakoba-chatbot-dev --follow
```
Chat in the browser and watch lines appear. Press **Ctrl+C** to stop.

## 2. Logs Insights (console)
1. Console → **CloudWatch** → left menu **Logs** → **Logs Insights**.
2. **Select log group(s)** → `/aws/lambda/nakoba-chatbot-dev`.
3. Paste a query, click **Run query**:

All chats, newest first:
```
fields @timestamp, outcome, blockReason, model, tokensUsed.input, tokensUsed.output, durationMs
| filter event = "chat_request"
| sort @timestamp desc
| limit 50
```
Responsible-AI events:
```
fields @timestamp, outcome, responsibleAI.piiTypes.0, responsibleAI.blockCategory, responsibleAI.promptInjectionAttempt
| filter @message like /"piiDetected":true/ or @message like /"harmfulContentBlocked":true/ or @message like /"promptInjectionAttempt":true/
| sort @timestamp desc
```
Token usage (cost driver):
```
filter event = "chat_request" and outcome = "success"
| stats sum(tokensUsed.input) as inputTokens, sum(tokensUsed.output) as outputTokens, count() as chats by bin(1h)
```

## 3. Metrics and alarms
- **Lambda** → `nakoba-chatbot-dev` → tab **Monitor**: invocations, errors, duration, throttles.
- Want a dashboard? **CloudWatch → Dashboards → Create dashboard** and add those Lambda metrics (a good extra exercise).
- **CloudWatch → Alarms**: `high-error-rate`, `p99-latency`, `lambda-throttles`, `responsible-ai-block`. Alarms email you via SNS (if you confirmed the subscription in [04](04-deploy.md)).
- **WAF & Shield → Web ACLs → Global (CloudFront)** → your ACL → **Overview**: allowed vs blocked requests (your SQL-injection test from step 05 shows here).
- **Billing → Budgets**: your monthly budget.

More detail: [`Nakoba PROD/06_MONITORING_OBSERVABILITY.md`](../Nakoba%20PROD/06_MONITORING_OBSERVABILITY.md).

[Next: CI/CD →](07-ci-cd.md)
