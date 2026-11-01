# 00 · Project Overview — Prince Enterprise AI Chatbot

[🏠 Lab home](../README.md) · [Next: Prerequisites →](01-prerequisites.md)

## The problem
Companies want a ChatGPT-style assistant for their staff and customers, but a "quick demo" chatbot is not safe to put in front of real users:
- API keys end up hard-coded in the code or browser.
- Anyone can spam it and run up a huge AI bill.
- Users paste personal data (emails, phone numbers, card numbers) that then leaves the company.
- People try to "jailbreak" the AI.
- Nobody can see what happened when something goes wrong.

## What you will build
A production-style, **serverless** AI chatbot on AWS, with Anthropic **Claude** as the AI, deployed entirely with **Terraform** (Infrastructure as Code) and **GitHub Actions** (CI/CD).

```
 Browser
   │  HTTPS
   ▼
 CloudFront (CDN, HTTPS, security headers) ◄── AWS WAF (OWASP rules, SQLi, bad IPs, rate limit)
   │                         │
   │ "/"                     │ "/chat", "/health"
   ▼                         ▼
 S3 (private website)    API Gateway (HTTP API)
                             │
                             ▼
                         Lambda (Node.js 24)
                         ├─ rate limit ──────► DynamoDB (per-IP counters, auto-expire)
                         ├─ input validation
                         ├─ responsible AI: block harmful content, redact PII, strip prompt injection
                         ├─ API key ─────────► Secrets Manager
                         ├─ call Claude ─────► Anthropic API (claude-sonnet-5-5)
                         └─ audit log ───────► CloudWatch Logs → alarms → SNS email
```

| Layer | Service | Why |
|---|---|---|
| Website | S3 + CloudFront (Origin Access Control) | Bucket stays private; only CloudFront can read it |
| Protection | AWS WAF v2 | Blocks common web attacks before they reach your code |
| API | API Gateway HTTP API | Cheap, fast, managed HTTPS endpoint |
| Logic | AWS Lambda (Node.js 24) | Pay only when someone chats; scales automatically |
| AI | Anthropic Claude | The model that writes the answers |
| Secrets | AWS Secrets Manager | API key never in code, Git or the browser |
| Abuse control | DynamoDB | Per-IP rate limiting with TTL |
| Observability | CloudWatch Logs, alarms, AWS Budgets, SNS | You get an email when errors, latency or spend go up |
| IaC | Terraform | The whole stack is created and deleted with one command |
| CI/CD | GitHub Actions | Tests, security scans (npm audit, Checkov), deployments |

## What you will learn
1. Setting up AWS and Anthropic accounts safely.
2. Remote Terraform state (S3 + DynamoDB locking).
3. Deploying a full serverless stack with one script.
4. Testing guardrails: PII redaction, harmful-content blocking, rate limiting.
5. Monitoring with CloudWatch Logs Insights and alarms.
6. CI/CD with GitHub Actions.
7. Tearing everything down so you stop paying.

## Time and cost
| | |
|---|---|
| Time | 2–3 hours the first time (CloudFront alone takes 5–15 minutes to create) |
| AWS cost | A few cents to ~$1 if you destroy it the same day. WAF (~$5/month + ~$1 per rule) and Secrets Manager ($0.40/month) are charged pro-rata, so **always run the cleanup** in [09](09-cleanup.md) |
| Anthropic cost | Pay-as-you-go credits. A lab session of a few dozen messages costs cents. Check current prices at https://www.anthropic.com/pricing |

## The steps
| # | Step |
|---|---|
| 01 | [Prerequisites: accounts and tools](01-prerequisites.md) |
| 02 | [Clone the repo and set your email](02-clone-and-configure.md) |
| 03 | [Bootstrap: AWS login, state bucket, API key](03-bootstrap.md) |
| 04 | [Deploy](04-deploy.md) |
| 05 | [Test everything](05-test.md) |
| 06 | [Monitoring](06-monitoring.md) |
| 07 | [CI/CD with GitHub Actions (optional)](07-ci-cd.md) |
| 08 | [Make a change and roll back](08-update-and-rollback.md) |
| 09 | [Clean up](09-cleanup.md) ⚠️ do not skip |
| 10 | [Troubleshooting](10-troubleshooting.md) |
| 11 | [Share your work](11-share-your-work.md) |

[Next: Prerequisites →](01-prerequisites.md)
