#!/usr/bin/env bash
# AC2 In the pipeline, the three sample files run through the application give the reports and outcomes in
# `docs/reference/`, unchanged, and HBase's `sales_agg` holds the reports' rows.
# Runs in the JDK 8 job after the reference compare (scripts/reference/acceptance/AC4, which runs
# scripts/reference/capture.sh into target/reference-run, with the Spark job on this build's Spark). Checks:
# - the reference compare step succeeded (REFERENCE_COMPARE, the step outcome given by the workflow), and
#   docs/reference/ is unchanged since the merge base with origin/main;
# - the scan of sales_agg that capture.sh took (target/reference-run/hbase-sales_agg.txt) holds, for every data row
#   of each reference report, the row key <date>_<region>_<productId> with totalQty, totalAmount and orderCount equal
#   to the report's;
# - this card's new HBase test (AC2SmallRegionIsReadTest: a flushed region far under 1 MB is read in full) ran and
#   passed, none skipped.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/spark35/acceptance/lib.sh

[ "${REFERENCE_COMPARE:-}" = success ] || fail "the reference compare ended '${REFERENCE_COMPARE:-not run}'"

base=$(merge_base)
ref_changed=$(git diff --name-only "$base" HEAD -- docs/reference/)
[ -z "$ref_changed" ] || fail "docs/reference/ changed since $base: $ref_changed"

scan=${REFERENCE_RUN:-target/reference-run}/hbase-sales_agg.txt
[ -s "$scan" ] || fail "$scan is missing or empty (capture.sh scans sales_agg after the run)"

n=0
for report in docs/reference/report-*.csv; do
  while IFS=, read -r date region product qty amount count; do
    [ "$date" = date ] && continue
    [ -n "$date" ] || continue
    key="${date}_${region}_${product}"
    for pair in "totalQty=$qty" "totalAmount=$amount" "orderCount=$count"; do
      col=${pair%%=*}; val=${pair#*=}; val=${val//./\\.}
      grep -qE "^ *${key} +column=a:${col}, .*value=${val}\$" <(tr -d '\r' < "$scan") \
        || fail "sales_agg has no $key a:$col = $val (from $report)"
    done
    n=$((n + 1))
  done < <(tr -d '\r' < "$report")
done
[ "$n" -gt 0 ] || fail "the reference reports have no data rows"

require_clean_report "$SMALL_REGION_REPORT"
pass "AC2 the reference compare holds, docs/reference/ unchanged, sales_agg holds all $n report rows, small regions are read"
