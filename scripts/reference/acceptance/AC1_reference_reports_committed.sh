#!/usr/bin/env bash
# AC1 report-20261113.csv and report-20261115.csv, written by today's application (Java 8, Spark 2.4.8, HBase 1.4)
# from sample-data/sales-20261113.csv and sales-20261115.csv, are committed under docs/reference/, with the commit of
# main they came from.
# Checks: both reports are tracked by git, start with the header and have data rows; docs/reference/README.md names
# the commit in a line "Code from main commit: <sha>", and that commit is on origin/main.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/reference/acceptance/lib.sh

for d in $REPORT_DATES; do
  f="$REF/report-$d.csv"
  require_report "$f"
  git ls-files --error-unmatch "$f" > /dev/null 2>&1 || fail "$f is not committed"
done
[ -f "$REF/README.md" ] || fail "$REF/README.md is missing"
sha=$(lines "$REF/README.md" | sed -nE 's/^.*Code from main commit: `?([0-9a-f]{7,40})`?.*$/\1/p' | head -1)
[ -n "$sha" ] || fail "$REF/README.md has no line 'Code from main commit: <sha>'"
git cat-file -e "$sha^{commit}" 2>/dev/null || fail "commit $sha is not in this repository"
git rev-parse --verify -q origin/main > /dev/null || fail "origin/main is not fetched"
git merge-base --is-ancestor "$sha" origin/main || fail "commit $sha is not on origin/main"
pass "AC1 both reference reports committed, from main commit $sha"
