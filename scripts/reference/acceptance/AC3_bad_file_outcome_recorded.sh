#!/usr/bin/env bash
# AC3 The outcome of sample-data/sales-bad.csv is recorded under docs/reference/: the final status, the error text,
# and whether a report is written.
# Checks docs/reference/sales-bad.outcome.txt is committed and holds the file, a final status, a non-empty error
# text and report=yes or no.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/reference/acceptance/lib.sh

f="$REF/sales-bad.outcome.txt"
[ -f "$f" ] || fail "$f is missing"
git ls-files --error-unmatch "$f" > /dev/null 2>&1 || fail "$f is not committed"
[ "$(outcome_field "$f" file)" = sales-bad.csv ] || fail "$f does not name file=sales-bad.csv"
st=$(outcome_field "$f" status)
case "$st" in FAILED|COMPLETED|REJECTED) ;; *) fail "$f has no final status (status=$st)" ;; esac
[ -n "$(outcome_field "$f" error)" ] || [ "$st" != FAILED ] || fail "$f: status FAILED with no error text"
case "$(outcome_field "$f" report)" in yes|no) ;; *) fail "$f does not say report=yes or report=no" ;; esac
pass "AC3 sales-bad.csv outcome recorded: status=$st, report=$(outcome_field "$f" report)"
