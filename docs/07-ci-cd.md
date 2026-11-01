# 07 · CI/CD with GitHub Actions (optional)

[← Monitoring](06-monitoring.md) · [🏠 Lab home](../README.md) · [Next: Update and roll back →](08-update-and-rollback.md)

You need **your own fork** (see [02](02-clone-and-configure.md)).

| Workflow | Runs when | Does |
|---|---|---|
| `ci.yml` | Every push / pull request | npm audit, 15 unit tests (offline), Snyk (only if `SNYK_TOKEN` is set), Checkov IaC scan, `terraform validate` |
| `cd-staging.yml` | Push to `main`, **only if** variable `ENABLE_CD=true` | Deploys `staging`, then smoke tests |
| `cd-prod.yml` | Manually, **only if** `ENABLE_CD=true` | Asks you to type `deploy-prod`, waits for approval, deploys `prod`, tags a release |

CI works straight after forking: no secrets needed. CD stays switched off until you turn it on, so a fork never fails for missing AWS keys.

## 1. Turn on Actions in your fork
Your fork on GitHub → tab **Actions** → **I understand my workflows, go ahead and enable them**. Push any commit and watch **CI** go green.

## 2. Add secrets (only for CD)
Repo → **Settings** → left **Secrets and variables** → **Actions** → tab **Secrets** → **New repository secret**, one at a time:

| Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | From your IAM user's `.csv` |
| `AWS_SECRET_ACCESS_KEY` | From your IAM user's `.csv` |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `nakoba-terraform-state-<your 12-digit account id>` |
| `TF_LOCK_TABLE` | `nakoba-terraform-locks` |
| `SNYK_TOKEN` | Optional: from https://app.snyk.io → Account settings |

## 3. Create environments
**Settings** → **Environments** → **New environment**:
1. `staging` → **Configure environment** → save.
2. `production` → tick **Required reviewers** → add yourself → **Save protection rules**.

## 4. Set your email in the staging and prod tfvars
Edit `terraform/environments/staging.tfvars` and `prod.tfvars` (`owner_email`), then commit and push.

## 5. Switch CD on
**Settings** → **Secrets and variables** → **Actions** → tab **Variables** → **New repository variable** → Name `ENABLE_CD`, Value `true` → **Add variable**.

Now every push to `main` deploys **staging**. For **prod**: **Actions** → **CD — Deploy to Production** → **Run workflow** → type `deploy-prod` and a short note → **Run workflow** → approve when asked.

> Each environment is a full separate stack and costs money. Destroy them when you're done: `./scripts/destroy.sh staging` and `./scripts/destroy.sh prod`. (`prod` keeps its S3 buckets on purpose; empty them in the S3 console first if destroy complains.)

Details: [`Nakoba PROD/04_CI_CD_PIPELINE.md`](../Nakoba%20PROD/04_CI_CD_PIPELINE.md).

[Next: Update and roll back →](08-update-and-rollback.md)
