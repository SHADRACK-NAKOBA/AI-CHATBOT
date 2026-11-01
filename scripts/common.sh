#!/usr/bin/env bash
# Shared settings for the lab scripts. Sourced by the other scripts — do not run directly.
set -euo pipefail

# Git Bash on Windows rewrites arguments that start with "/" into Windows paths
# (e.g. "/*" becomes "C:/Program Files/Git/*"). This turns that off.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"
# shellcheck disable=SC2034  # used by the scripts that source this file
LAMBDA_DIR="$REPO_ROOT/ai-chatbot/lambda"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
SECRET_NAME="${SECRET_NAME:-nakoba/anthropic-api-key}"
LOCK_TABLE="${LOCK_TABLE:-nakoba-terraform-locks}"

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { red "ERROR: $*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed or not on your PATH. See docs/01-prerequisites.md, then close and reopen Git Bash."
}

check_env_arg() {
  case "${1:-}" in
    dev|staging|prod) ;;
    *) die "Usage: $0 <dev|staging|prod>   (students: use dev)";;
  esac
}

aws_account_id() {
  aws sts get-caller-identity --query Account --output text 2>/dev/null \
    || die "AWS CLI is not logged in. Run 'aws configure' (see docs/03-bootstrap.md, step 1)."
}

state_bucket() { echo "nakoba-terraform-state-$(aws_account_id)"; }

tf_init() {
  local env="$1"
  step "terraform init (state: s3://$(state_bucket)/nakoba-chatbot/$env)"
  terraform -chdir="$TF_DIR" init -reconfigure -input=false \
    -backend-config="bucket=$(state_bucket)" \
    -backend-config="key=nakoba-chatbot/$env/terraform.tfstate" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="dynamodb_table=$LOCK_TABLE" \
    -backend-config="encrypt=true"
}
