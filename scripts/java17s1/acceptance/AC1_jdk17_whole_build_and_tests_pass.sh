#!/usr/bin/env bash
# AC1 The Java 17 pipeline job builds everything and every existing test passes, none skipped, tests unchanged.
# Runs in the JDK 17 job after the whole-reactor build and test steps: the running java is 17; the surefire
# reports of common, spark-job and workflow-app show at least as many tests as before the change (30, 8 and 30,
# docs/cards/SBJ17-16.md, Assess) with none failed, in error or skipped; and no existing test source has been
# changed, deleted or renamed since the merge base with origin/main (tests added by later cards are allowed).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17s1/acceptance/lib.sh

[ "$(java_major)" = 17 ] || fail "this job runs java $(java_major), not 17"
for m in common spark-job workflow-app; do
  [ -d "$m/target/classes" ] || fail "$m was not built in this job"
done
require_module_green common 30
require_module_green spark-job 8
require_module_green workflow-app 30

base=$(merge_base)
changed=$(git diff --name-status --diff-filter=MDR "$base" HEAD -- ':(glob)**/src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "existing test sources changed since $(git rev-parse --short "$base")"
fi
pass "AC1 the whole build (common, spark-job, workflow-app) passes every existing test on JDK 17, tests unchanged"
