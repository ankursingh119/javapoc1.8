#!/usr/bin/env bash
# AC2 Its JDK 8 job runs `mvn -B install` then `mvn -B test` for common, spark-job and workflow-app,
#     and passes on the card's pull request.
# Static check of the jdk8 job, then (run inside that job after `mvn -B test`) the surefire reports of all three
# modules on JDK 8. The job's green result on the pull request is read from the pipeline.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

require_workflow
block=$(job_block jdk8)
[ -n "$block" ] || fail "job jdk8 is missing"
echo "$block" | grep -qE "java-version: '?8'?[[:space:]]*$" || fail "job jdk8 does not set up JDK 8"
install_line=$(echo "$block" | grep -nE 'run: mvn -B install[[:space:]]*$' | head -1 | cut -d: -f1)
test_line=$(echo "$block" | grep -nE 'run: mvn -B test[[:space:]]*$' | head -1 | cut -d: -f1)
[ -n "$install_line" ] || fail "job jdk8 has no step 'mvn -B install'"
[ -n "$test_line" ] || fail "job jdk8 has no step 'mvn -B test'"
[ "$install_line" -lt "$test_line" ] || fail "job jdk8 runs 'mvn -B test' before 'mvn -B install'"
if echo "$block" | grep -q 'dependency:go-offline'; then fail "job jdk8 uses dependency:go-offline"; fi
if echo "$block" | grep -qE '^    continue-on-error: true'; then fail "job jdk8 is allowed to fail"; fi

java -version 2>&1 | grep -q 'version "1\.8\.' || fail "this is not JDK 8: $(java -version 2>&1 | head -1)"
for module in common spark-job workflow-app; do
  reports=$(ls "$module"/target/surefire-reports/TEST-*.xml 2>/dev/null || true)
  [ -n "$reports" ] || fail "$module: no surefire reports (its tests did not run)"
  for report in $reports; do
    [ "$(suite_attr "$report" failures)" -eq 0 ] || fail "$report: tests failed"
    [ "$(suite_attr "$report" errors)" -eq 0 ] || fail "$report: tests errored"
  done
  echo "  $module: $(echo "$reports" | wc -l) test classes, none failed"
done
pass "AC2 the JDK 8 job installs then tests, and common, spark-job and workflow-app pass"
