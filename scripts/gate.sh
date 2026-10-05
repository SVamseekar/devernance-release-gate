#!/usr/bin/env bash
# Calls the Assurance OS CI release gate and fails the job on BLOCKED (or REVIEW with fail-on: review).
# Any other outcome (HTTP error, API down, unreadable answer) also fails the job: it never passes silently.
set -euo pipefail

: "${AOS_KEY:=}" "${AOS_SYSTEM:=}" "${AOS_URL:=}" "${AOS_FAIL_ON:=blocked}"
: "${GITHUB_OUTPUT:=/dev/null}" "${GITHUB_STEP_SUMMARY:=/dev/null}"

fail() { echo "::error::$1"; exit 1; }

[[ -n "$AOS_KEY" && -n "$AOS_SYSTEM" ]] || fail "api-key and system-id are required"
[[ -n "$AOS_URL" ]] || fail "api-url is required (the base URL of your Assurance OS workspace)"
[[ "$AOS_FAIL_ON" == "blocked" || "$AOS_FAIL_ON" == "review" ]] || fail "fail-on must be 'blocked' or 'review', got '$AOS_FAIL_ON'"
command -v jq > /dev/null || fail "jq is required on the runner"

echo "::add-mask::$AOS_KEY"
body=$(mktemp)
trap 'rm -f "$body"' EXIT
status=$(curl -sS -o "$body" -w '%{http_code}' --max-time 30 -G \
  -H "X-Api-Key: $AOS_KEY" -H "Accept: application/json" \
  --data-urlencode "systemId=$AOS_SYSTEM" \
  "${AOS_URL%/}/api/v1/ci/release-gate" 2> "$body.err") || true
status=${status:-000}
if [[ "$status" != "200" ]]; then
  detail=$(head -c 300 "$body" 2> /dev/null || true)
  [[ -n "$detail" ]] || detail=$(head -c 300 "$body.err" 2> /dev/null || true)
  rm -f "$body.err"
  fail "Assurance OS returned HTTP $status: ${detail:-no response}"
fi
rm -f "$body.err"

decision=$(jq -er '.decision | strings' "$body" 2> /dev/null) || fail "Assurance OS answered HTTP 200 but not a release-gate response: $(head -c 200 "$body")"
case "$decision" in
  PASS | REVIEW | BLOCKED) ;;
  *) fail "Assurance OS returned an unexpected decision '$decision'" ;;
esac
blockers=$(jq -c '.blockers // []' "$body")

echo "decision=$decision" >> "$GITHUB_OUTPUT"
echo "blockers=$blockers" >> "$GITHUB_OUTPUT"
{
  echo "### Assurance OS release gate: $decision"
  echo ""
  jq -r '.blockers[]? | "- " + .' "$body"
  echo ""
  echo "_Evidence and readiness signal, not legal advice._"
} >> "$GITHUB_STEP_SUMMARY"

echo "Assurance OS release gate: $decision"
jq -r '.blockers[]? | "  blocker: " + .' "$body"

if [[ "$decision" == "BLOCKED" ]]; then
  fail "Release gate is BLOCKED"
fi
if [[ "$AOS_FAIL_ON" == "review" && "$decision" == "REVIEW" ]]; then
  fail "Release gate is REVIEW and fail-on is 'review'"
fi
