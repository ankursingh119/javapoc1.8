#!/usr/bin/env bash
# AC4 In the pipeline's JDK 17 job, the production WorkflowServer runs on JDK 17 against HBase in Docker (the Spark
# job itself still on JDK 8): sales-20261113.csv and sales-20261115.csv reach WAITING_APPROVAL and, once approved,
# COMPLETED with reports equal to docs/reference/, and sales-bad.csv is rejected the recorded way.
# Runs scripts/java17/run-workflow-server.sh into target/java17-run (or checks an existing run: JAVA17_RUN=<folder>),
# then: the server ran on java 17 with Spring 5.x in its jar; each Spark job ran on java 8; both good files waited
# for approval; and SBJ17-8's comparison (scripts/reference/acceptance/AC4_compare_with_reference.sh, unchanged)
# holds on this run: COMPLETED, reports equal to the reference line for line, sales-bad.csv's outcome as recorded.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

run=${JAVA17_RUN:-}
if [ -z "$run" ]; then
  run=target/java17-run
  bash scripts/java17/run-workflow-server.sh "$run"
fi

grep -q 'version "17' "$run/java-version.txt" || fail "the server did not run on java 17: $(head -1 "$run/java-version.txt")"
jar=workflow-app/target/workflow-app.jar
# ReactiveAdapterRegistry exists from Spring 5.0; Spring 6 would bring jakarta, which AC6 refuses.
unzip -l "$jar" | grep -q 'org/springframework/core/ReactiveAdapterRegistry.class' \
  || fail "$jar does not carry Spring 5 (no org.springframework.core.ReactiveAdapterRegistry)"
[ -s "$run/spark-standin.log" ] || fail "no Spark job was started through the JDK 8 stand-in"
if grep -E 'version "' "$run/spark-standin.log" | grep -vq 'version "1\.8'; then
  fail "a Spark job ran on a java other than 8: $(grep -E 'version "' "$run/spark-standin.log" | sort -u)"
fi
for d in 20261113 20261115; do
  [ "$(cat "$run/waited-approval-sales-$d.csv.txt" 2>/dev/null)" = yes ] || fail "sales-$d.csv did not reach WAITING_APPROVAL"
done

REFERENCE_RUN="$run" bash scripts/reference/acceptance/AC4_compare_with_reference.sh
pass "AC4 the production server on JDK 17 (Spark job on JDK 8) matches the reference: two reports and the sales-bad.csv rejection"
