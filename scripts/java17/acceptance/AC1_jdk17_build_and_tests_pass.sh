#!/usr/bin/env bash
# AC1 On JDK 17 in the pipeline, `mvn -B install` and `mvn -B test` for common and workflow-app pass with Spring at
# 5.3.x; the existing tests are unchanged and pass, and the new tests pass.
# Runs in the JDK 17 job after the build and test steps: the running java is 17, the build resolves Spring 5.3.x,
# and the surefire reports of common and workflow-app show at least as many tests as before the change (30 and 30,
# docs/cards/SBJ17-9.md, Assess) with none failed, in error or skipped. That the tests are unchanged is AC5.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

[ "$(java_major)" = 17 ] || fail "this job runs java $(java_major), not 17"
require_spring_53
require_module_green common 30
require_module_green workflow-app 30
pass "AC1 common and workflow-app build and pass their tests on JDK 17 with Spring 5.3"
