# 11 · Share your work

[← Troubleshooting](10-troubleshooting.md) · [🏠 Lab home](../README.md)

## Screenshots to take before cleanup
1. The chatbot answering a question.
2. A PII test showing `[EMAIL REDACTED]`.
3. The `./scripts/smoke-test.sh dev` output with 6 PASS.
4. CloudWatch Logs Insights query results.
5. WAF overview with blocked requests.
6. A green GitHub Actions CI run (if you forked).

## LinkedIn post outline
- **Problem:** demo chatbots leak keys and personal data, and can run up unlimited bills.
- **What I built:** a serverless enterprise AI chatbot on AWS with Claude, deployed with Terraform and GitHub Actions.
- **How:** CloudFront + WAF → API Gateway → Lambda → Claude; Secrets Manager, DynamoDB rate limiting, PII redaction, audit logs and alarms.
- **Business value:** safe to put in front of users, costs cents when idle, and the whole stack can be recreated or deleted in one command.
- **Problems I solved:** retired model IDs, Lambda concurrency limits on new accounts, WAF bypass, CloudFront logging permissions.

Tag it with `#AWS #Terraform #GenAI #Serverless #ResponsibleAI` and mention the **Prince** hands-on labs.

## Interview talking points
- Why put the API key in Secrets Manager rather than a Lambda environment variable?
- Why does the frontend call `/chat` on CloudFront instead of the API Gateway URL? (So every request passes the WAF.)
- How does the system stop one user from running up the AI bill? (WAF rate rule + DynamoDB per-IP limit + `max_tokens` + AWS Budget.)
- What are the trade-offs of keyword-based content filtering? (False positives; production teams add a classifier or a guardrail service.)

[🏠 Back to the lab home](../README.md)
