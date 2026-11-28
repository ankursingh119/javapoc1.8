#!/usr/bin/env bash
# AC2 With server and job on Java 17, both sample reports equal the reference and the bad file is rejected as
# recorded.
# Runs SBJ17-9's scripts/java17/run-workflow-server.sh into target/java17s1-run with the job started through the
# Java 17 stand-in scripts/java17/spark-submit-local.sh (SPARK_SUBMIT_STANDIN), or checks an existing run
# (JAVA17S1_RUN=<folder>). Then: the server ran on java 17; at least one Spark job was started and every one ran on
# java 17; both good files waited for approval; and SBJ17-8's comparison
# (scripts/reference/acceptance/AC4_compare_with_reference.sh, unchanged) holds: COMPLETED, reports equal to
# docs/reference/ line for line, sales-bad.csv's outcome as recorded.
# Needs HBase up, workflow-app/target/workflow-app.jar, spark-job's classes and target/local-classpath.txt.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17s1/acceptance/lib.sh

run=${JAVA17S1_RUN:-}
if [ -z "$run" ]; then
  run=target/java17s1-run
  SPARK_SUBMIT_STANDIN=scripts/java17/spark-submit-local.sh bash scripts/java17/run-workflow-server.sh "$run" \
    || fail "the run with server and job on java 17 did not finish (see $run/server.log)"
fi

grep -q 'version "17' "$run/java-version.txt" || fail "the server did not run on java 17: $(head -1 "$run/java-version.txt")"
[ -s "$run/spark-standin.log" ] || fail "no Spark job was started through the stand-in"
versions=$(grep -E 'version "' "$run/spark-standin.log" | sed -nE 's/.*version "([^"]+)".*/\1/p' | sort -u)
[ -n "$versions" ] || fail "the stand-in log names no java version"
if echo "$versions" | grep -vq '^17'; then
  fail "a Spark job ran on a java other than 17: $(echo "$versions" | tr '\n' ' ')"
fi
for d in 20261113 20261115; do
  [ "$(cat "$run/waited-approval-sales-$d.csv.txt" 2>/dev/null)" = yes ] || fail "sales-$d.csv did not reach WAITING_APPROVAL"
done

REFERENCE_RUN="$run" bash scripts/reference/acceptance/AC4_compare_with_reference.sh
pass "AC2 server and Spark job both on JDK 17 match the reference: two reports and the sales-bad.csv rejection"
