#!/usr/bin/env bash
# Runs scripts/gate.sh against test/mock-server.py and checks exit codes, outputs, and messages.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/../scripts/gate.sh"
port=8787
python3 "$here/mock-server.py" "$port" & server=$!
trap 'kill $server 2>/dev/null' EXIT
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done

failures=0
work=$(mktemp -d)

# run <name> <expected-exit> <expected-text-or-empty> <key> <system> <url> <fail-on>
run() {
  local name=$1 want=$2 text=$3
  export GITHUB_OUTPUT="$work/$name.out" GITHUB_STEP_SUMMARY="$work/$name.md"
  : > "$GITHUB_OUTPUT"; : > "$GITHUB_STEP_SUMMARY"
  GATE_API_KEY=$4 GATE_SYSTEM_ID=$5 GATE_API_URL=$6 GATE_FAIL_ON=$7 bash "$gate" > "$work/$name.log" 2>&1
  local got=$?
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $name: exit $got, want $want"; cat "$work/$name.log"; failures=$((failures + 1)); return
  fi
  if [[ -n "$text" ]] && ! grep -qF -- "$text" "$work/$name.log" "$GITHUB_OUTPUT" "$GITHUB_STEP_SUMMARY"; then
    echo "FAIL $name: missing '$text'"; cat "$work/$name.log"; failures=$((failures + 1)); return
  fi
  echo "ok   $name"
}

url="http://127.0.0.1:$port"
run pass             0 "decision=PASS"                       test-key pass    "$url" blocked
run pass-summary     0 "Devernance release gate: PASS"     test-key pass    "$url" blocked
run blocked          1 "CONTROL:HUMAN_OVERSIGHT"             test-key blocked "$url" blocked
run blocked-output   1 'blockers=["CONTROL:HUMAN_OVERSIGHT"' test-key blocked "$url" blocked
run review-default   0 "decision=REVIEW"                     test-key review  "$url" blocked
run review-strict    1 "REVIEW"                              test-key review  "$url" review
run wrong-key        1 "HTTP 401"                            bad-key  pass    "$url" blocked
run unknown-system   1 "HTTP 404"                            test-key nope    "$url" blocked
run plan-limit       1 "Monthly gate runs used up"           test-key limit   "$url" blocked
run api-down         1 "HTTP 000"                            test-key pass    "http://127.0.0.1:1" blocked
run not-json         1 "not a release-gate response"         test-key garbage "$url" blocked
run odd-decision     1 "unexpected decision 'MAYBE'"         test-key odd     "$url" blocked
run missing-key      1 "api-key and system-id are required"  ""       pass    "$url" blocked
run missing-system   1 "api-key and system-id are required"  test-key ""      "$url" blocked
run missing-url      1 "api-url is required"                 test-key pass    ""     blocked
run bad-fail-on      1 "fail-on must be"                     test-key pass    "$url" sometimes
run trailing-slash   0 "decision=PASS"                       test-key pass    "$url/" blocked

rm -rf "$work"
if (( failures > 0 )); then echo "$failures failing"; exit 1; fi
echo "all passed"
