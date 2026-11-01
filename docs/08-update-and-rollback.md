# 08 · Make a change and roll back

[← CI/CD](07-ci-cd.md) · [🏠 Lab home](../README.md) · [Next: Clean up →](09-cleanup.md)

## 1. Change the bot's personality
1. Open `ai-chatbot/lambda/index.js` and find `SYSTEM_PROMPT`.
2. Add a line such as: `Always end your answer with a one-line summary starting with "In short:".`
3. Save, test offline, deploy:
   ```bash
   cd ai-chatbot/lambda && npm test && cd ../..
   ./scripts/deploy.sh dev
   ```
   Terraform sees the zip changed and updates only the Lambda (`1 changed`).
4. Chat in the browser and see the new behaviour.

## 2. Change the website
Edit `ai-chatbot/frontend/index.html` (for example the title), then:
```bash
./scripts/deploy.sh dev
DIST_ID=$(terraform -chdir=terraform output -raw cloudfront_distribution_id)
MSYS_NO_PATHCONV=1 aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```
`MSYS_NO_PATHCONV=1` stops Git Bash turning `/*` into a Windows path.

## 3. Switch the model without touching code
```bash
./scripts/deploy.sh dev   # after setting anthropic_model in dev.tfvars, e.g.:
# anthropic_model = "claude-haiku-5-5"
```
Add `anthropic_model = "..."` to `terraform/environments/dev.tfvars`. Model IDs: https://docs.claude.com/en/docs/about-claude/models/overview

## 4. Roll back
Everything is in Git, so rolling back means redeploying an earlier version:
```bash
git log --oneline -5              # find the change
git revert --no-edit <COMMIT_SHA> # creates an "undo" commit
./scripts/deploy.sh dev
```
Not committed yet? `git checkout -- ai-chatbot/lambda/index.js` then deploy.

[Next: Clean up →](09-cleanup.md)
