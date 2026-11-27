#!/usr/bin/env bash
# AC4 A JDK 17 job runs the same commands beside it, and its failure does not fail the pipeline.
# Static check of the jdk17 job. The pipeline's run conclusion (green while jdk17 is red) is read from the pipeline.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

require_workflow
jdk8=$(job_block jdk8)
jdk17=$(job_block jdk17)
[ -n "$jdk17" ] || fail "job jdk17 is missing"
echo "$jdk17" | grep -qE "java-version: '?17'?[[:space:]]*$" || fail "job jdk17 does not set up JDK 17"
echo "$jdk17" | grep -qE '^    continue-on-error: true[[:space:]]*$' || fail "job jdk17 is not allowed to fail (continue-on-error)"
if echo "$jdk17" | grep -qE '^    needs:'; then fail "job jdk17 waits on another job, so it does not run beside it"; fi
if echo "$jdk8" | grep -qE '^    needs:'; then fail "job jdk8 waits on another job, so it does not run beside it"; fi
# The same commands: every run step of jdk8 is in jdk17, in the same order (acceptance checks that read
# JDK 8 reports are jdk8's own and are left out).
cmds() { echo "$1" | grep -E '^ +(- )?run: ' | sed -E 's/^ +(- )?run: //' | grep -v 'scripts/ci/acceptance/'; }
[ "$(cmds "$jdk8")" = "$(cmds "$jdk17")" ] || {
  echo "jdk8 runs:";  cmds "$jdk8"
  echo "jdk17 runs:"; cmds "$jdk17"
  fail "job jdk17 does not run the same commands as jdk8"
}
pass "AC4 a JDK 17 job runs the same commands beside the JDK 8 job and may fail"
