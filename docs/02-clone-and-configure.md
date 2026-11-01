# 02 · Clone the repo and set your email

[← Prerequisites](01-prerequisites.md) · [🏠 Lab home](../README.md) · [Next: Bootstrap →](03-bootstrap.md)

## 1. Clone
Open **Git Bash** (Windows) or **Terminal** (macOS/Linux):
```bash
cd ~/Desktop
git clone https://github.com/SHADRACK-NAKOBA/AI-CHATBOT.git
cd AI-CHATBOT
ls
```
You should see `ai-chatbot  docs  Nakoba PROD  README.md  scripts  terraform`.

> Want your own copy on GitHub for CI/CD ([step 07](07-ci-cd.md))? First click **Fork** on the repo page, then clone **your** fork: `git clone https://github.com/<YOUR-USERNAME>/AI-CHATBOT.git`.

## 2. Put your email in the dev settings
AWS sends alarm and budget emails here, and Terraform refuses to run until you change it.

1. Open the folder in an editor. With VS Code: `code .` (or open `terraform/environments/dev.tfvars` in Notepad).
2. Open **`terraform/environments/dev.tfvars`**.
3. Change this line:
   ```hcl
   owner_email                   = "CHANGE_ME@example.com" # <-- REQUIRED ...
   ```
   to your real email, for example:
   ```hcl
   owner_email                   = "jane.doe@gmail.com"
   ```
4. **Save** (Ctrl+S / Cmd+S).

Check it from Git Bash:
```bash
grep owner_email terraform/environments/dev.tfvars
```

### Other settings in `dev.tfvars` (leave as they are for the lab)
| Setting | Default | Meaning |
|---|---|---|
| `aws_region` | `us-east-1` | Keep it: CloudFront's WAF must live in us-east-1 |
| `lambda_reserved_concurrency` | `-1` | No reservation. New AWS accounts have only 10 concurrent Lambdas, so reserving more fails |
| `rate_limit_per_minute` | `200` | Chat requests per IP per minute before HTTP 429 |
| `monthly_budget_usd` | `50` | AWS Budget email alert threshold |
| `allowed_origin` | `*` | CORS; fine for dev |

The Claude model is set in `terraform/variables.tf` (`anthropic_model`, default `claude-sonnet-5-5`). You can change it without editing code.

## 3. (Optional) Run the unit tests — no AWS or API key needed
```bash
cd ai-chatbot/lambda
npm ci
npm test
cd ../..
```
Expected: `# pass 15` and `# fail 0`. The tests use fake AWS and Claude clients.

[Next: Bootstrap →](03-bootstrap.md)
