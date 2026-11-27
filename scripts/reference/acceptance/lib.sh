#!/usr/bin/env bash
# Shared helpers for the SBJ17-8 acceptance checks. Sourced, not run. The checks run from the repository root.

REF=${REFERENCE_DIR:-docs/reference}
HEADER="date,region,productId,totalQty,totalAmount,orderCount"
REPORT_DATES="20261113 20261115"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# A file's lines with carriage returns removed (Windows and Linux line endings count as the same).
lines() { tr -d '\r' < "$1"; }

# Fail unless a report exists, starts with the header and has at least one data row.
require_report() {
  local f="$1" rows
  [ -f "$f" ] || fail "$f is missing"
  [ "$(lines "$f" | head -1)" = "$HEADER" ] || fail "$f does not start with the header $HEADER"
  rows=$(lines "$f" | tail -n +2 | grep -c . || true)
  [ "$rows" -gt 0 ] || fail "$f has the header and no data rows"
}

# One key=value field of an outcome file.
outcome_field() { lines "$1" | sed -n "s/^$2=//p" | head -1; }
