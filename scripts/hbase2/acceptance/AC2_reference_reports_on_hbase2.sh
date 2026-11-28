#!/usr/bin/env bash
# AC2 In the pipeline, the three sample files run through the application (the app run of the reference compare,
# the production server and the local Docker Spark cluster) give the reports and outcomes in `docs/reference/`,
# unchanged, and HBase's `sales_agg` holds the reports' rows.
# The workflow passes the outcomes of the steps that run the application; this check reads them, so it runs after
# them. Since card SBJ17-17 (docs/cards/SBJ17-17.md) there is one job, on Java 17, and all three are read there:
# - REFERENCE_COMPARE (scripts/reference/acceptance/AC4: the app compared with docs/reference/) and CLUSTER_RUN
#   (scripts/spark35/cluster: the job on the Docker Spark cluster, 12 rows) must be success; the scan of sales_agg
#   taken by capture.sh (target/reference-run/hbase-sales_agg.txt) must hold every data row of each reference report
#   with the same totalQty, totalAmount and orderCount;
# - SERVER_COMPARE (scripts/java17s1/acceptance/AC2: the production server and its Spark job on Java 17 compared with
#   docs/reference/; it replaced SBJ17-9's server-on-17, job-on-8 compare) must be success.
# And: docs/reference/ is unchanged since the merge base with origin/main, and the HBase server those runs used
# reports 2.x.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

base=$(merge_base)
ref_changed=$(git diff --name-only "$base" HEAD -- docs/reference/)
[ -z "$ref_changed" ] || fail "docs/reference/ changed since $base: $ref_changed"

server=$(hbase_server_version)
[[ "$server" =~ ^2\. ]] || fail "the runs used HBase server '${server:-none}', not 2.x"

[ "${REFERENCE_COMPARE:-}" = success ] || fail "the reference compare ended '${REFERENCE_COMPARE:-not run}'"
[ "${CLUSTER_RUN:-}" = success ] || fail "the Docker Spark cluster run ended '${CLUSTER_RUN:-not run}'"
[ "${SERVER_COMPARE:-}" = success ] || fail "the production server compare ended '${SERVER_COMPARE:-not run}'"
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
pass "AC2 on HBase $server: the app run, the production server and the Docker Spark cluster match docs/reference/ (unchanged), sales_agg holds all $n report rows"
