#!/usr/bin/env bash
# AC3 That job starts HBase from `docker/local/docker-compose.yml`, and the HBase end-to-end test
#     (`SalesAggregatorHBaseTest`) runs rather than skips.
# Also the person's decision (SBJ17-Q3, item 2): the JDK 8 job fails when that test is skipped.
# Static check of the jdk8 job, then (inside that job after `mvn -B test`) the test's surefire report.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

require_workflow
block=$(job_block jdk8)
[ -n "$block" ] || fail "job jdk8 is missing"
echo "$block" | grep -q 'docker compose -f docker/local/docker-compose.yml up -d hbase' \
  || fail "job jdk8 does not start HBase from docker/local/docker-compose.yml"
echo "$block" | grep -q 'scripts/ci/acceptance/AC3_hbase_end_to_end_test_runs.sh' \
  || fail "job jdk8 does not run this check, so a skipped HBase test would not fail it"

require_clean_report spark-job/target/surefire-reports/TEST-com.example.salesbatch.spark.SalesAggregatorHBaseTest.xml
pass "AC3 HBase started from docker/local/docker-compose.yml and SalesAggregatorHBaseTest ran, none skipped"
