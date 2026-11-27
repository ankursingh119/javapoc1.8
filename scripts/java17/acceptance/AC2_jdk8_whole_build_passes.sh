#!/usr/bin/env bash
# AC2 On JDK 8 in the pipeline, the whole build still passes: spark-job builds and its tests pass, the HBase
# end-to-end test runs, and the reference-reports compare from SBJ17-8 shows no difference.
# Runs in the JDK 8 job after `mvn -B install` and `mvn -B test`: the running java is 8, the build resolves Spring
# 5.3.x, and all three modules pass at least the tests they had before (common 30, spark-job 7, workflow-app 30).
# The HBase end-to-end test (scripts/ci/acceptance/AC3) and the reference compare
# (scripts/reference/acceptance/AC4) are their own steps in the same job; this check reads their results through
# the step outcomes it is given (HBASE_E2E and REFERENCE_COMPARE, set by the workflow), so AC2 fails when either did.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

[ "$(java_major)" = 8 ] || fail "this job runs java $(java_major), not 8"
require_spring_53
require_module_green common 30
require_module_green spark-job 7
require_module_green workflow-app 30
[ "${HBASE_E2E:-}" = success ] || fail "the HBase end-to-end check ended '${HBASE_E2E:-not run}'"
[ "${REFERENCE_COMPARE:-}" = success ] || fail "the reference compare ended '${REFERENCE_COMPARE:-not run}'"
pass "AC2 the whole build passes on JDK 8 with Spring 5.3, the HBase end-to-end test ran and the reference compare holds"
