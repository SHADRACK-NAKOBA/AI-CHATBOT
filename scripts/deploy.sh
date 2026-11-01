#!/usr/bin/env bash
# Build the Lambda package and deploy everything with Terraform.
# Usage: ./scripts/deploy.sh dev        (add --yes to skip the confirmation prompt)
source "$(dirname "$0")/common.sh"
ENV="${1:-}"; check_env_arg "$ENV"
AUTO=""; [ "${2:-}" = "--yes" ] && AUTO="-auto-approve"
need aws; need terraform; need node; need npm

TFVARS="$TF_DIR/environments/$ENV.tfvars"
if grep -Eq '^[[:space:]]*owner_email[[:space:]]*=.*(CHANGE_ME|example\.com)' "$TFVARS"; then
  die "Open terraform/environments/$ENV.tfvars and replace CHANGE_ME@example.com with YOUR email (docs/02-clone-and-configure.md)."
fi
aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1 \
  || die "Secret '$SECRET_NAME' not found. Run ./scripts/bootstrap.sh first."

step "Installing Lambda dependencies (Terraform zips this folder)"
( cd "$LAMBDA_DIR" && npm ci --omit=dev --no-audit --no-fund )

tf_init "$ENV"

step "terraform apply ($ENV) — review the plan, then type: yes"
terraform -chdir="$TF_DIR" apply -input=false $AUTO -var-file="environments/$ENV.tfvars"

URL="$(terraform -chdir="$TF_DIR" output -raw cloudfront_domain)"
green ""
green "Deployed! Your chatbot: $URL"
yellow "CloudFront can take 5-15 minutes to go live the first time."
yellow "Check your email inbox and click 'Confirm subscription' from AWS Notifications."
echo   "Next: ./scripts/smoke-test.sh $ENV"
