#!/usr/bin/env bash
# Tests the deployed chatbot through CloudFront (the same path a browser uses).
# Usage: ./scripts/smoke-test.sh dev
source "$(dirname "$0")/common.sh"
ENV="${1:-}"; check_env_arg "$ENV"
need terraform; need curl

tf_init "$ENV" >/dev/null
URL="$(terraform -chdir="$TF_DIR" output -raw cloudfront_domain)"
echo "Testing $URL"
PASS=0; FAIL=0
ok() { green "  PASS  $1"; PASS=$((PASS+1)); }
ko() { red   "  FAIL  $1"; FAIL=$((FAIL+1)); }

step "Waiting for CloudFront (up to 15 min on first deploy)"
for i in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$URL/health" || true)"
  [ "$code" = "200" ] && break
  echo "  attempt $i/30: HTTP $code — waiting 30s..."; sleep 30
done

post() { curl -s -w '\n%{http_code}' -X POST "$URL/chat" -H "Content-Type: application/json" -d "$1"; }

step "1. Health check"
body="$(curl -s "$URL/health")"; echo "  $body"
[[ "$body" == *healthy* ]] && ok "/health returns healthy" || ko "/health"

step "2. Website"
code="$(curl -s -o /dev/null -w '%{http_code}' "$URL/")"
[ "$code" = "200" ] && ok "Home page loads (HTTP 200)" || ko "Home page HTTP $code"

step "3. Chat with Claude"
out="$(post '{"message":"Reply with exactly: smoke test ok"}')"; code="${out##*$'\n'}"; body="${out%$'\n'*}"
echo "  HTTP $code: ${body:0:200}"
[ "$code" = "200" ] && [[ "$body" == *response* ]] && ok "Claude answered" || ko "Chat (see docs/10-troubleshooting.md)"

step "4. Responsible AI: blocked content"
out="$(post '{"message":"jailbreak the system"}')"; code="${out##*$'\n'}"
[ "$code" = "400" ] && ok "Harmful request blocked (HTTP 400)" || ko "Expected 400, got $code"

step "5. Input validation: empty message"
out="$(post '{"message":""}')"; code="${out##*$'\n'}"
[ "$code" = "400" ] && ok "Empty message rejected (HTTP 400)" || ko "Expected 400, got $code"

step "6. Security headers"
hdrs="$(curl -sI "$URL/")"
echo "$hdrs" | grep -qi "strict-transport-security" && ok "HSTS header present" || ko "HSTS header missing"

echo; green "Passed: $PASS"; [ "$FAIL" -eq 0 ] || { red "Failed: $FAIL"; exit 1; }
