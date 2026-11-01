# 09 · Clean up ⚠️ Don't skip this

[← Update and roll back](08-update-and-rollback.md) · [🏠 Lab home](../README.md) · [Next: Troubleshooting →](10-troubleshooting.md)

WAF and Secrets Manager bill even when nobody uses the chatbot.

## 1. Destroy the chatbot
```bash
./scripts/destroy.sh dev
```
Type **`yes`**. Takes 5–15 minutes (CloudFront is slow to delete). Expected: `Destroy complete! Resources: 4x destroyed.`

## 2. Remove the bootstrap resources too (when finished with the lab)
```bash
./scripts/destroy.sh dev --all
```
Answer `y`. This also deletes the API-key secret (immediately, no 7-day wait), the Terraform state bucket and the lock table. Only do this when **no** environment (dev/staging/prod) is still deployed.

## 3. Housekeeping
1. **Anthropic**: platform.claude.com → **API keys** → disable or delete `prince-chatbot-lab`.
2. **AWS IAM**: IAM → Users → `chatbot-lab-admin` → **Security credentials** → access key → **Actions → Deactivate**, then **Delete**. (Or delete the user.)
3. **GitHub** (if you did CI/CD): set `ENABLE_CD` to `false` or delete it, and delete the AWS secrets.

## 4. Check nothing is left
```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=nakoba-chatbot --query 'ResourceTagMappingList[].ResourceARN'
aws resourcegroupstaggingapi get-resources --region us-east-1 --tag-filters Key=Project,Values=nakoba-chatbot --query 'ResourceTagMappingList[].ResourceARN'
```
Expected: `[]`. (Deleted resources can show here for up to a few hours.) Tomorrow, check **Billing → Bills**.

[Next: Troubleshooting →](10-troubleshooting.md)
