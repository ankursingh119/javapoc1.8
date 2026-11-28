#!/usr/bin/env bash
# AC2 On the pipeline's Java job, the whole build still passes: spark-job builds and its tests pass, the HBase
# end-to-end test runs, and the reference-reports compare from SBJ17-8 shows no difference.
# Card SBJ17-17 (docs/cards/SBJ17-17.md) replaced the JDK 8 job with one JDK 17 job; this check moved with it and
# asserts java 17 where it asserted java 8 (it was AC2_jdk8_whole_build_passes.sh).
# Runs in the JDK 17 job after the build and test steps: the running java is 17, the build resolves Spring
# 5.3.x, and all three modules pass at least the tests they had before (common 30, spark-job 7, workflow-app 30).
# The HBase end-to-end test (scripts/ci/acceptance/AC3) and the reference compare
# (scripts/reference/acceptance/AC4) are their own steps in the same job; this check reads their results through
# the step outcomes it is given (HBASE_E2E and REFERENCE_COMPARE, set by the workflow), so AC2 fails when either did.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

[ "$(java_major)" = 17 ] || fail "this job runs java $(java_major), not 17"
require_spring_53
require_module_green common 30
require_module_green spark-job 7
require_module_green workflow-app 30
[ "${HBASE_E2E:-}" = success ] || fail "the HBase end-to-end check ended '${HBASE_E2E:-not run}'"
[ "${REFERENCE_COMPARE:-}" = success ] || fail "the reference compare ended '${REFERENCE_COMPARE:-not run}'"
pass "AC2 the whole build passes on JDK 17 with Spring 5.3, the HBase end-to-end test ran and the reference compare holds"
