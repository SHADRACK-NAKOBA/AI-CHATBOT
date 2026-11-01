# 10 · Troubleshooting

[← Clean up](09-cleanup.md) · [🏠 Lab home](../README.md) · [Next: Share your work →](11-share-your-work.md)

First, read the Lambda logs. They show the real error:
```bash
aws logs tail /aws/lambda/nakoba-chatbot-dev --since 15m
```

| Symptom | Cause | Fix |
|---|---|---|
| `command not found: aws / terraform / node` | Tool not installed or PATH not refreshed | Install ([01](01-prerequisites.md)), close and reopen Git Bash, or restart the PC |
| `$'\r': command not found` when running a script | Windows line endings | `git config --global core.autocrlf input`, then delete the folder and clone again |
| `Permission denied` running `./scripts/x.sh` | No execute bit (macOS/Linux) | `chmod +x scripts/*.sh` or run `bash scripts/x.sh dev` |
| `AWS CLI is not logged in` / `Unable to locate credentials` | `aws configure` not done | [03 step 1](03-bootstrap.md) |
| `InvalidClientTokenId` / `SignatureDoesNotMatch` | Wrong or deactivated keys, or copy-paste spaces | Create a new access key and run `aws configure` again |
| `owner_email must be set...` / script says replace CHANGE_ME | Email not set | [02 step 2](02-clone-and-configure.md) |
| `Secret 'nakoba/anthropic-api-key' not found` | Bootstrap not run | `./scripts/bootstrap.sh` |
| `You can't create this secret because a secret with this name is already scheduled for deletion` | A previous cleanup | Run `./scripts/bootstrap.sh` again; it restores it |
| `Error acquiring the state lock` | An earlier run was interrupted | Make sure nothing else is running, then `terraform -chdir=terraform force-unlock <LOCK_ID>` (ID is in the error) |
| `Backend configuration changed` | Switching env | The scripts use `-reconfigure`; always deploy via the scripts |
| `Your account must be verified before you can add new CloudFront resources` | New AWS account | Open **Support Center → Create case → Account and billing** and ask for CloudFront to be enabled; retry after they reply |
| `InvalidParameterValueException ... ReservedConcurrentExecutions ... below its minimum value` | New accounts have only 10 concurrent Lambdas | Keep `lambda_reserved_concurrency = -1`, or request a quota increase in **Service Quotas** |
| `WAFUnavailableEntityException` or WAF errors | WAF still being created | Run `./scripts/deploy.sh dev` again |
| Browser shows `AccessDenied` XML or a blank page | CloudFront still spreading, or cached old page | Wait 10 minutes; create an invalidation ([08](08-update-and-rollback.md)) |
| Chat says *"Service temporarily unavailable"* / HTTP 500 | Usually the Claude call failed | Check logs: `401 authentication_error` → wrong key, rerun bootstrap and replace it; `400 credit balance is too low` → buy Anthropic credits; `404 not_found_error model` → model retired, set `anthropic_model` ([08](08-update-and-rollback.md)) |
| HTTP 429 *Rate limit exceeded* | You hit the per-IP limit | Wait one minute, or raise `rate_limit_per_minute` |
| HTTP 400 for an innocent question | The keyword block list (e.g. "jailbreak") | Expected; see `ai-chatbot/lambda/middleware/responsibleAI.js` |
| HTTP 403 from CloudFront | WAF blocked the request | WAF console → your ACL → **Sampled requests** shows which rule |
| `npm ci` fails: `missing from lock file` | You edited `package.json` | Run `npm install` in `ai-chatbot/lambda` and commit the new `package-lock.json` |
| `destroy` fails: `BucketNotEmpty` (prod only) | prod buckets are protected | Empty the buckets in the S3 console, then destroy again |
| Git Bash turns `/*` into `C:/Program Files/Git/*` | MSYS path conversion | Prefix the command with `MSYS_NO_PATHCONV=1` |
| No alarm emails | SNS subscription not confirmed | Click the confirmation email; SNS console → Subscriptions should say *Confirmed* |

Still stuck? Copy the **full** error (no keys!) and open an Issue on the repo.

[Next: Share your work →](11-share-your-work.md)
