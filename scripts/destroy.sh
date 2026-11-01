#!/usr/bin/env bash
# Deletes everything this lab created in one environment so you stop paying.
# Usage: ./scripts/destroy.sh dev            -> removes the chatbot stack
#        ./scripts/destroy.sh dev --all      -> also deletes the API-key secret, state bucket and lock table
source "$(dirname "$0")/common.sh"
ENV="${1:-}"; check_env_arg "$ENV"
need aws; need terraform; need npm

# Terraform re-zips the Lambda folder during destroy, so the dependencies must exist.
( cd "$LAMBDA_DIR" && { [ -d node_modules ] || npm ci --omit=dev --no-audit --no-fund; } )

tf_init "$ENV"
step "terraform destroy ($ENV) — type: yes"
terraform -chdir="$TF_DIR" destroy -input=false -var-file="environments/$ENV.tfvars"
green "Chatbot stack '$ENV' destroyed."

if [ "${2:-}" = "--all" ]; then
  read -r -p "Also delete the API-key secret, Terraform state bucket and lock table? Only do this if no other environment is deployed. [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    BUCKET="$(state_bucket)"
    step "Deleting secret $SECRET_NAME"
    aws secretsmanager delete-secret --secret-id "$SECRET_NAME" --force-delete-without-recovery >/dev/null 2>&1 || yellow "Secret not found."
    step "Emptying and deleting state bucket $BUCKET (all versions)"
    if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
      for kind in Versions DeleteMarkers; do
        while :; do
          objs="$(aws s3api list-object-versions --bucket "$BUCKET" --max-items 500 \
            --query "{Objects: ${kind}[].{Key:Key,VersionId:VersionId}}" --output json)"
          [[ "$objs" == *VersionId* ]] || break
          aws s3api delete-objects --bucket "$BUCKET" --delete "$objs" >/dev/null
        done
      done
      aws s3api delete-bucket --bucket "$BUCKET"
    fi
    step "Deleting lock table $LOCK_TABLE"
    aws dynamodb delete-table --table-name "$LOCK_TABLE" >/dev/null 2>&1 || yellow "Table not found."
    green "Everything removed."
  fi
fi
yellow "Tip: check AWS Billing > Bills tomorrow to confirm charges have stopped."
