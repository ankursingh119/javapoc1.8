#!/usr/bin/env bash
# AC1 In the pipeline's Java job, `mvn -B install` and `mvn -B test` pass with spark-job built on Spark 3.5 and
# Scala 2.12; the existing tests are unchanged and pass, and the new tests pass.
# Card SBJ17-17 (docs/cards/SBJ17-17.md) replaced the JDK 8 job with one JDK 17 job; this check moved with it and
# asserts java 17 where it asserted java 8 (it was AC1_jdk8_build_on_spark35.sh).
# Runs in the JDK 17 job after the build and test steps (a red Maven step stops the job before this check,
# so a pass here also means both passed). Checks: the running java is 17; spark-job resolves spark.version 3.5.x,
# scala.version 2.12.x and scala.binary.version 2.12; no existing file under any src/test changed, was deleted or
# renamed since the merge base with origin/main (new files are allowed); every module passes at least the tests it
# had before (common 30, spark-job 7, workflow-app 30) plus this card's new test, none skipped.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/spark35/acceptance/lib.sh

[ "$(java_major)" = 17 ] || fail "this job runs java $(java_major), not 17"

spark=$(spark_job_prop spark.version)
scala=$(spark_job_prop scala.version)
scalabin=$(spark_job_prop scala.binary.version)
[[ "$spark" =~ ^3\.5\.[0-9]+$ ]] || fail "spark-job builds on Spark '$spark', not 3.5.x"
[[ "$scala" =~ ^2\.12\.[0-9]+$ ]] || fail "spark-job builds on Scala '$scala', not 2.12.x"
[ "$scalabin" = 2.12 ] || fail "spark-job's scala.binary.version is '$scalabin', not 2.12"
echo "spark-job: Spark $spark, Scala $scala"

base=$(merge_base)
changed=$(git diff --name-status --diff-filter=MDRT "$base" HEAD -- '*/src/test/**' 'src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "existing test sources changed since $base (only new test files are allowed)"
fi

require_module_green common 30
require_module_green spark-job 8
require_module_green workflow-app 30
require_clean_report "$SMALL_REGION_REPORT"
pass "AC1 JDK 17 build on Spark $spark and Scala $scala: existing tests unchanged and passing, new test passing"
