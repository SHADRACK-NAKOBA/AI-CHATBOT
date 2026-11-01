# 03 · Bootstrap: AWS login, state bucket and API key

[← Clone and configure](02-clone-and-configure.md) · [🏠 Lab home](../README.md) · [Next: Deploy →](04-deploy.md)

## 1. Log the AWS CLI in
In Git Bash, from the `AI-CHATBOT` folder:
```bash
aws configure
```
Answer the 4 questions using the `.csv` you downloaded in [01](01-prerequisites.md):
```
AWS Access Key ID [None]:      AKIA................   (from the csv)
AWS Secret Access Key [None]:  ........................ (from the csv)
Default region name [None]:    us-east-1
Default output format [None]:  json
```
Check:
```bash
aws sts get-caller-identity
```
You should see your 12-digit `Account` and an `Arn` ending in `user/chatbot-lab-admin`.

## 2. Run the bootstrap script
```bash
./scripts/bootstrap.sh
```
It creates, once per AWS account:
| # | Resource | Name | Why |
|---|---|---|---|
| 1 | S3 bucket (versioned, encrypted, private) | `nakoba-terraform-state-<ACCOUNT_ID>` | Stores Terraform's state remotely |
| 2 | DynamoDB table | `nakoba-terraform-locks` | Stops two people applying at once |
| 3 | Secrets Manager secret | `nakoba/anthropic-api-key` | Holds your Claude key; only the Lambda can read it |

When asked, **paste your `sk-ant-...` key** and press **Enter**. Nothing appears while you paste; that is on purpose. (Paste in Git Bash: **Shift+Insert** or right-click → Paste.)

Expected end:
```
Secret saved. Bootstrap complete — next: ./scripts/deploy.sh dev
```
Running it again is safe; it skips what exists and offers to replace the key.

## 3. See it in the console (optional)
- **S3** → Buckets → `nakoba-terraform-state-...`
- **DynamoDB** → Tables → `nakoba-terraform-locks`
- **Secrets Manager** → Secrets → `nakoba/anthropic-api-key` (the value is hidden unless you click **Retrieve secret value**)

<details><summary>What the script does, if you prefer manual commands</summary>

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket --bucket nakoba-terraform-state-$ACCOUNT_ID
aws s3api put-bucket-versioning --bucket nakoba-terraform-state-$ACCOUNT_ID --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name nakoba-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST
aws secretsmanager create-secret --name nakoba/anthropic-api-key \
  --secret-string '{"api_key":"sk-ant-YOUR_KEY"}'
```
The secret must be JSON with the field `api_key`; the Lambda reads exactly that.
</details>

[Next: Deploy →](04-deploy.md)
