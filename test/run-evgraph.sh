#!/usr/bin/env bash
# Runs scripts/evgraph.sh against the fixtures. Set EVGRAPH_BIN to an installed evgraph to skip the install.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/evgraph.sh"
fx="$here/fixtures"
failures=0
work=$(mktemp -d)

# check <name> <expected-exit> <expected-text-or-empty> <paths>
check() {
  local name=$1 want=$2 text=$3
  export GITHUB_STEP_SUMMARY="$work/$name.md"
  : > "$GITHUB_STEP_SUMMARY"
  EVGRAPH_SCAN=$4 EVGRAPH_VERSION=0.1.3 bash "$script" > "$work/$name.log" 2>&1
  local got=$?
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $name: exit $got, want $want"; cat "$work/$name.log"; failures=$((failures + 1)); return
  fi
  if [[ -n "$text" ]] && ! grep -qF -- "$text" "$work/$name.log" "$GITHUB_STEP_SUMMARY"; then
    echo "FAIL $name: missing '$text'"; cat "$work/$name.log"; failures=$((failures + 1)); return
  fi
  echo "ok   $name"
}

check consistent     0 "approval-precedes-deployment" "$fx/model_card.json $fx/approval.json $fx/deployment.json"
check summary        0 "Evgraph promotion scan: passed" "$fx/model_card.json $fx/approval.json $fx/deployment.json"
check inconsistent   1 "Evgraph promotion scan: failed" "$fx/model_card.json $fx/approval.json $fx/deployment-before-approval.json"
check two-paths      1 "evgraph-scan needs three paths" "$fx/model_card.json $fx/approval.json"
check missing-file   1 "not found: $fx/nope.json" "$fx/model_card.json $fx/approval.json $fx/nope.json"

rm -rf "$work"
if (( failures > 0 )); then echo "$failures failing"; exit 1; fi
echo "all passed"
