# 04 · Deploy

[← Bootstrap](03-bootstrap.md) · [🏠 Lab home](../README.md) · [Next: Test →](05-test.md)

## 1. Run the deploy script
```bash
./scripts/deploy.sh dev
```
What happens:
1. **Checks**: your email is set, tools are installed, the secret exists.
2. **`npm ci --omit=dev`** in `ai-chatbot/lambda` (Terraform zips that folder, including `node_modules`, into the Lambda package).
3. **`terraform init`** connects to your state bucket (`nakoba-chatbot/dev/terraform.tfstate`).
4. **`terraform apply`** shows the plan: about **48 resources to add**.
5. Read the plan, then type **`yes`** and press **Enter**.

The apply takes **10–20 minutes**; most of it is CloudFront. Don't close the window.

Expected end:
```
Apply complete! Resources: 4x added, 0 changed, 0 destroyed.
Outputs:
cloudfront_domain = "https://dxxxxxxxxxxxx.cloudfront.net"
...
Deployed! Your chatbot: https://dxxxxxxxxxxxx.cloudfront.net
```

## 2. Confirm the alert email ⚠️
Within a few minutes you get an email **"AWS Notification - Subscription Confirmation"**. Click **Confirm subscription**. Without this you won't receive alarm emails. (Check spam.)

## 3. Open the chatbot
Copy the `https://...cloudfront.net` URL into your browser. If you see an error, wait 5 minutes and refresh; CloudFront is still spreading worldwide.

Get the URL again any time:
```bash
terraform -chdir=terraform output -raw cloudfront_domain; echo
```

## 4. What was created (look in the console)
| Console | What to look at |
|---|---|
| **CloudFront** → Distributions | Your distribution, two origins (S3 and API Gateway), behaviours `/chat` and `/health` |
| **WAF & Shield** → Web ACLs (region: **Global (CloudFront)**) | `nakoba-chatbot-dev` and its 4 managed rule groups + rate rule |
| **API Gateway** → APIs | `nakoba-chatbot-dev` HTTP API with routes `POST /chat`, `GET /health`, `OPTIONS /chat` |
| **Lambda** → Functions | `nakoba-chatbot-dev`, runtime Node.js 24.x; **Configuration → Environment variables** shows `ANTHROPIC_MODEL` and no secrets |
| **S3** | `nakoba-chatbot-dev-frontend-<account>` (private) and a logs bucket |
| **DynamoDB** | Rate-limit table with TTL |
| **CloudWatch** → Alarms | 4 alarms (errors, p99 latency, throttles, responsible-AI blocks) |
| **Billing** → Budgets | Monthly budget for the project |

All resources are tagged `Project=nakoba-chatbot`, `Environment=dev`, `Owner=<your email>`.

<details><summary>Manual commands instead of the script</summary>

```bash
cd ai-chatbot/lambda && npm ci --omit=dev && cd ../..
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform -chdir=terraform init \
  -backend-config="bucket=nakoba-terraform-state-$ACCOUNT_ID" \
  -backend-config="key=nakoba-chatbot/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=nakoba-terraform-locks"
terraform -chdir=terraform apply -var-file=environments/dev.tfvars
```
Note: `-chdir` goes **before** the sub-command (`terraform -chdir=terraform output`, not `terraform output -chdir=...`).
</details>

[Next: Test →](05-test.md)
