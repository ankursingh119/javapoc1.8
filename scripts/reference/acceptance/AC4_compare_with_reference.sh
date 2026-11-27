#!/usr/bin/env bash
# AC4 A script compares a fresh run of the three files with the reference and fails when a report differs, is
# missing or has no data rows, or when sales-bad.csv is not rejected the recorded way. It runs in the pipeline's
# JDK 8 job on every push.
# Runs scripts/reference/capture.sh into target/reference-run (or compares an existing run: REFERENCE_RUN=<folder>),
# then: each report exists, has data rows and equals the reference line for line (carriage returns removed);
# each good file ended COMPLETED; sales-bad.csv's outcome equals the recorded one exactly and wrote no report.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/reference/acceptance/lib.sh

run=${REFERENCE_RUN:-}
if [ -z "$run" ]; then
  run=target/reference-run
  bash scripts/reference/capture.sh "$run"
fi

for d in $REPORT_DATES; do
  st=$(outcome_field "$run/outcome-sales-$d.csv.txt" status 2>/dev/null || true)
  [ "$st" = COMPLETED ] || fail "sales-$d.csv ended '$st', not COMPLETED (see $run)"
  require_report "$run/reports/report-$d.csv"
  require_report "$REF/report-$d.csv"
  if ! diff <(lines "$REF/report-$d.csv") <(lines "$run/reports/report-$d.csv") > "$run/diff-$d.txt"; then
    cat "$run/diff-$d.txt" >&2
    fail "report-$d.csv differs from the reference (< reference, > this run)"
  fi
done

bad_ref="$REF/sales-bad.outcome.txt"
bad_run="$run/outcome-sales-bad.csv.txt"
[ -f "$bad_ref" ] || fail "$bad_ref is missing"
[ -f "$bad_run" ] || fail "this run has no outcome for sales-bad.csv"
if ! diff <(lines "$bad_ref") <(lines "$bad_run") > "$run/diff-bad.txt"; then
  cat "$run/diff-bad.txt" >&2
  fail "sales-bad.csv was not rejected the recorded way (< reference, > this run)"
fi
bad_date=$(outcome_field "$bad_run" businessDate)
[ ! -f "$run/reports/report-$bad_date.csv" ] || fail "sales-bad.csv wrote report-$bad_date.csv"
pass "AC4 a fresh run matches the reference: two reports and the sales-bad.csv rejection"
