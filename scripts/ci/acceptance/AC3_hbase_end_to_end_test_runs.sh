#!/usr/bin/env bash
# AC3 That job starts HBase from `docker/local/docker-compose.yml`, and the HBase end-to-end test
#     (`SalesAggregatorHBaseTest`) runs rather than skips.
# Also the person's decision (SBJ17-Q3, item 2): the required job fails when that test is skipped.
# Card SBJ17-17 (docs/cards/SBJ17-17.md) replaced the JDK 8 job (jdk8) with one JDK 17 job (jdk17), which is now
# the job this check reads.
# Static check of the jdk17 job, then (inside that job after `mvn -B test`) the test's surefire report.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

require_workflow
block=$(job_block jdk17)
[ -n "$block" ] || fail "job jdk17 is missing"
echo "$block" | grep -q 'docker compose -f docker/local/docker-compose.yml up -d hbase' \
  || fail "job jdk17 does not start HBase from docker/local/docker-compose.yml"
echo "$block" | grep -q 'scripts/ci/acceptance/AC3_hbase_end_to_end_test_runs.sh' \
  || fail "job jdk17 does not run this check, so a skipped HBase test would not fail it"

require_clean_report spark-job/target/surefire-reports/TEST-com.example.salesbatch.spark.SalesAggregatorHBaseTest.xml
pass "AC3 HBase started from docker/local/docker-compose.yml and SalesAggregatorHBaseTest ran, none skipped"
