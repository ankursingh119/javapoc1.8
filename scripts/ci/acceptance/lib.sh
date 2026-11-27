#!/usr/bin/env bash
# Shared helpers for the SBJ17-2 acceptance checks. Sourced, not run.
# Run every check from the repository root.

WORKFLOW=".github/workflows/ci.yml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

require_workflow() {
  [ -f "$WORKFLOW" ] || fail "$WORKFLOW does not exist"
}

# Print one job's block of the workflow: from "  <id>:" under "jobs:" to the next job at the same indent.
job_block() {
  awk -v id="$1" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^ #]/ { injobs = 0 }
    injobs && $0 ~ "^  " id ":[[:space:]]*$" { printing = 1; next }
    injobs && printing && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { printing = 0 }
    printing { print }
  ' "$WORKFLOW"
}

# Print the "on:" block of the workflow.
on_block() {
  awk '
    /^"?on"?:/ { printing = 1; next }
    printing && /^[^ #]/ { printing = 0 }
    printing { print }
  ' "$WORKFLOW"
}

# Read one attribute of the <testsuite> element of a surefire report.
suite_attr() {
  grep -o "<testsuite [^>]*" "$1" | head -1 | grep -o " $2=\"[0-9]*\"" | grep -o "[0-9]\+"
}

# Fail unless a surefire report exists and shows tests > 0 and no failure, error or skip.
require_clean_report() {
  local report="$1" tests failures errors skipped
  [ -f "$report" ] || fail "no surefire report $report (the tests did not run)"
  tests=$(suite_attr "$report" tests); failures=$(suite_attr "$report" failures)
  errors=$(suite_attr "$report" errors); skipped=$(suite_attr "$report" skipped)
  [ "${tests:-0}" -gt 0 ] || fail "$report: no tests ran"
  [ "${failures:-0}" -eq 0 ] || fail "$report: $failures failed"
  [ "${errors:-0}" -eq 0 ] || fail "$report: $errors errors"
  [ "${skipped:-0}" -eq 0 ] || fail "$report: $skipped skipped"
  echo "  $report: $tests tests, 0 failed, 0 errors, 0 skipped"
}
