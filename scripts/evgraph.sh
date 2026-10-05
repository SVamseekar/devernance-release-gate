#!/usr/bin/env bash
# Runs `evgraph scan-promotion --gate` on a Model Card, approval record, and deployment record.
# EVGRAPH_SCAN holds the three paths in that order. EVGRAPH_BIN skips the install (used by tests).
set -euo pipefail

: "${EVGRAPH_SCAN:=}" "${EVGRAPH_VERSION:=0.1.3}" "${GITHUB_STEP_SUMMARY:=/dev/null}"

fail() { echo "::error::$1"; exit 1; }

read -r -a paths <<< "$EVGRAPH_SCAN"
(( ${#paths[@]} == 3 )) || fail "evgraph-scan needs three paths: model card, approval record, deployment record (got ${#paths[@]})"
for path in "${paths[@]}"; do
  [[ -f "$path" ]] || fail "evgraph-scan file not found: $path"
done

if [[ -z "${EVGRAPH_BIN:-}" ]]; then
  venv="${RUNNER_TEMP:-$(mktemp -d)}/evgraph-venv"
  python3 -m venv "$venv" || fail "python3 -m venv failed; add actions/setup-python before this action"
  "$venv/bin/pip" install --quiet "evgraph-cli==$EVGRAPH_VERSION" || fail "could not install evgraph-cli==$EVGRAPH_VERSION"
  EVGRAPH_BIN="$venv/bin/evgraph"
fi

report=$(mktemp)
trap 'rm -f "$report"' EXIT
set +e
"$EVGRAPH_BIN" scan-promotion --model-card "${paths[0]}" --approval "${paths[1]}" --deployment "${paths[2]}" \
  --format markdown --gate > "$report"
code=$?
set -e
cat "$report"

if (( code == 0 )); then
  verdict="passed"
elif (( code == 1 )); then
  verdict="failed"
else
  verdict="errored (exit $code)"
fi
{
  echo "### Evgraph promotion scan: $verdict"
  echo ""
  cat "$report"
} >> "$GITHUB_STEP_SUMMARY"

(( code == 0 )) || fail "Evgraph promotion scan: $verdict"
