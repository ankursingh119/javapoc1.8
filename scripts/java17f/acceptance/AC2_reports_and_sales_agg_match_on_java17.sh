#!/usr/bin/env bash
# AC2 On Java 17 reports and sales_agg match the reference.
# Runs in the Java 17 job after the run with server and job on Java 17 (scripts/java17s1/acceptance/AC2, which runs
# SBJ17-8's reference compare: both sample reports equal docs/reference/ and sales-bad.csv rejected as recorded) and
# after the Docker cluster run (scripts/java17s1/acceptance/AC3, which checks sales_agg holds exactly the reference
# rows). It reads their outcomes (JAVA17_COMPARE and JAVA17_CLUSTER, set by the workflow) and their output, and adds:
# - the server and every Spark job of that run ran on java 17 (target/java17s1-run);
# - the runtime image built from docker/ with no build argument (as the README and the cluster script build it)
#   runs java 17, so the cluster run on Java 17 is the default and not an option the pipeline passes;
# - spark-master, where the cluster run's driver ran, runs java 17.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

[ "${JAVA17_COMPARE:-}" = success ] || fail "the reference compare with server and job on java 17 ended '${JAVA17_COMPARE:-not run}'"
[ "${JAVA17_CLUSTER:-}" = success ] || fail "the Docker cluster run on java 17 ended '${JAVA17_CLUSTER:-not run}'"

run=${JAVA17S1_RUN:-target/java17s1-run}
grep -q 'version "17' "$run/java-version.txt" 2>/dev/null || fail "the server of $run did not run on java 17"
versions=$(grep -E 'version "' "$run/spark-standin.log" 2>/dev/null | sed -nE 's/.*version "([^"]+)".*/\1/p' | sort -u)
[ -n "$versions" ] || fail "no Spark job of $run names its java version"
if echo "$versions" | grep -vq '^17'; then
  fail "a Spark job of $run ran on java $(echo $versions)"
fi

image=salesbatch-runtime-default-check
docker build -q -t "$image" docker > /dev/null || fail "the image does not build from docker/ with its defaults"
v=$(docker run --rm "$image" java -version 2>&1 | tr -d '\r')
docker image rm -f "$image" > /dev/null 2>&1 || true
echo "$v" | grep -q 'version "17' || fail "the image built from docker/ with no build argument runs $(echo "$v" | grep -m1 version), not java 17"

m=$(docker exec spark-master java -version 2>&1 | tr -d '\r') || fail "spark-master is not running (the cluster run starts it)"
echo "$m" | grep -q 'version "17' || fail "spark-master runs $(echo "$m" | grep -m1 version), not java 17"
pass "AC2 on java 17 (server, Spark jobs, default image, cluster) both reports and sales_agg match the reference"
