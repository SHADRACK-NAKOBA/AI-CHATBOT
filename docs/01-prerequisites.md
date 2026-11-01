# 01 · Prerequisites: accounts and tools

[← Overview](00-overview.md) · [🏠 Lab home](../README.md) · [Next: Clone and configure →](02-clone-and-configure.md)

You need **3 accounts** and **5 tools**. Do this once.

## A. Accounts

### A1. AWS account
1. Go to https://aws.amazon.com and click **Create an AWS Account**.
2. Enter your email and an account name (e.g. `prince-lab`), verify the email, set the root password.
3. Choose **Personal**, fill in your details, add a payment card, verify your phone, pick the **Basic support – Free** plan.
4. Sign in to the console as the **root user**.
5. Top-right, click your account name → **Security credentials** → **Assign MFA device** and set up an authenticator app. (Protects your card.)

### A2. A lab IAM user with access keys (for the command line)
The scripts need programmatic access. Never create access keys for the root user.

1. In the console search bar type **IAM** → open it.
2. Left menu **Users** → **Create user**.
3. User name: `chatbot-lab-admin` → **Next**.
4. Choose **Attach policies directly** → tick **AdministratorAccess** → **Next** → **Create user**.
   > This lab creates IAM roles, WAF, CloudFront and more, so admin is the simplest choice for a personal lab account. Delete the user's keys at the end ([09](09-cleanup.md)).
5. Click the new user `chatbot-lab-admin` → tab **Security credentials** → **Create access key**.
6. Choose **Command Line Interface (CLI)** → tick the confirmation box → **Next** → **Create access key**.
7. Click **Download .csv file**. Keep it private. **Never** paste these keys in chat, code or GitHub.

### A3. Billing alert (recommended)
Console search → **Billing and Cost Management** → **Budgets** → **Create budget** → **Use a template** → **Zero spend budget** → enter your email → **Create budget**.

### A4. Anthropic API account (for Claude)
1. Go to https://platform.claude.com (the old console.anthropic.com link redirects there) and sign up.
2. Left menu **Billing** (or Settings → Billing) → **Buy credits** → add the minimum amount. The API does not work without credits.
3. Left menu **API keys** → **Create key** → name it `prince-chatbot-lab` → **Create**.
4. **Copy the key now** (it starts with `sk-ant-`). You can't see it again. Keep it in a password manager or a private note. You will paste it once in [step 03](03-bootstrap.md).

### A5. GitHub account
https://github.com/signup (free). Needed to clone the repo and, optionally, for CI/CD.

## B. Tools

| Tool | Version | Check with |
|---|---|---|
| Git (+ Git Bash on Windows) | any recent | `git --version` |
| AWS CLI | v2 | `aws --version` |
| Terraform | 1.5 or newer | `terraform -version` |
| Node.js (includes npm) | 22 or newer (24 LTS recommended) | `node -v` and `npm -v` |
| curl | any (built into Git Bash / macOS) | `curl --version` |

### Windows
1. Click **Start**, type **PowerShell**, right-click **Windows PowerShell** → **Run as administrator**.
2. Paste these one at a time (press **Enter** after each, accept any prompts):
   ```powershell
   winget install -e --id Git.Git
   winget install -e --id Amazon.AWSCLI
   winget install -e --id Hashicorp.Terraform
   winget install -e --id OpenJS.NodeJS.LTS
   ```
   No `winget`? Install manually: [Git](https://git-scm.com/download/win), [AWS CLI](https://awscli.amazonaws.com/AWSCLIV2.msi), [Terraform](https://developer.hashicorp.com/terraform/install), [Node.js LTS](https://nodejs.org).
3. **Close PowerShell.** Click **Start**, type **Git Bash**, open it. (Every command in this lab runs in **Git Bash**, not PowerShell or CMD.)
4. Check:
   ```bash
   git --version && aws --version && terraform -version && node -v && npm -v
   ```
   If one says `command not found`, restart your computer and try again (PATH updates).

### macOS
Open **Terminal** and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # skip if you have Homebrew
brew install git awscli node
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
git --version && aws --version && terraform -version && node -v
```

### Linux (Ubuntu)
Follow the official installers for [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [Terraform](https://developer.hashicorp.com/terraform/install) and [Node.js](https://nodejs.org/en/download), then run the same checks.

## ✅ Checklist
- [ ] AWS account with MFA on root
- [ ] IAM user `chatbot-lab-admin` and its access-key `.csv`
- [ ] Anthropic credits and an `sk-ant-...` key saved privately
- [ ] All five tools print a version in Git Bash / Terminal

[Next: Clone and configure →](02-clone-and-configure.md)
