#!/usr/bin/env bash
# AC2 In the pipeline, the three sample files run through the application (the JDK 8 job, the JDK 17 production
# server and the local Docker Spark cluster) give the reports and outcomes in `docs/reference/`, unchanged, and
# HBase's `sales_agg` holds the reports' rows.
# The workflow passes the outcomes of the steps that run the application; this check reads them, so it runs after
# them in each job:
# - JDK 8 job (AC2_JOB=jdk8): REFERENCE_COMPARE (scripts/reference/acceptance/AC4: the app on JDK 8 compared with
#   docs/reference/) and CLUSTER_RUN (scripts/spark35/cluster: the job on the Docker Spark cluster, 12 rows) must be
#   success; the scan of sales_agg taken by capture.sh (target/reference-run/hbase-sales_agg.txt) must hold every
#   data row of each reference report with the same totalQty, totalAmount and orderCount.
# - JDK 17 job (AC2_JOB=jdk17): SERVER_COMPARE (scripts/java17/acceptance/AC4: the production server on JDK 17
#   compared with docs/reference/) must be success.
# Both: docs/reference/ is unchanged since the merge base with origin/main, and the HBase server those runs used
# reports 2.x.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

job=${AC2_JOB:-jdk8}

base=$(merge_base)
ref_changed=$(git diff --name-only "$base" HEAD -- docs/reference/)
[ -z "$ref_changed" ] || fail "docs/reference/ changed since $base: $ref_changed"

server=$(hbase_server_version)
[[ "$server" =~ ^2\. ]] || fail "the runs used HBase server '${server:-none}', not 2.x"

case "$job" in
  jdk8)
    [ "${REFERENCE_COMPARE:-}" = success ] || fail "the JDK 8 reference compare ended '${REFERENCE_COMPARE:-not run}'"
    [ "${CLUSTER_RUN:-}" = success ] || fail "the Docker Spark cluster run ended '${CLUSTER_RUN:-not run}'"
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
    pass "AC2 on HBase $server: JDK 8 run and Docker Spark cluster match docs/reference/ (unchanged), sales_agg holds all $n report rows"
    ;;
  jdk17)
    [ "${SERVER_COMPARE:-}" = success ] || fail "the JDK 17 production server compare ended '${SERVER_COMPARE:-not run}'"
    pass "AC2 on HBase $server: the JDK 17 production server matches docs/reference/ (unchanged)"
    ;;
  *) fail "AC2_JOB is '$job', not jdk8 or jdk17" ;;
esac
