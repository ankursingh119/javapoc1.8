#!/usr/bin/env bash
# AC1 One Java 17 job, must pass; all tests pass unchanged, none skipped.
# Static, on .github/workflows/ci.yml: exactly one job; it sets up Java 17 and no other Java; it is not allowed to
# fail (no continue-on-error); its name is "JDK 17" (the check a person makes required on main, SBJ17-Q28 item 3).
# In that job, after `mvn -B install -DskipTests` and `mvn -B test -fae`: the running java is 17; common, spark-job
# and workflow-app were built; their surefire reports show at least the tests they had before (30, 8 and 30,
# docs/cards/SBJ17-17.md, Assess) with none failed, in error or skipped; and no existing file under any src/test was
# changed, deleted or renamed since the merge base with origin/main.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

[ -f "$WORKFLOW" ] || fail "$WORKFLOW is missing"
ids=$(job_ids)
n=$(printf '%s\n' "$ids" | grep -c . || true)
[ "$n" -eq 1 ] || fail "the pipeline has $n jobs ($(echo $ids)), not one"
job=$(printf '%s\n' "$ids" | head -1)
block=$(job_block_of "$job" < "$WORKFLOW")

versions=$(grep -oE "java-version:[[:space:]]*['\"]?[0-9.]+" "$WORKFLOW" | sed -E "s/.*:[[:space:]]*['\"]?//" | sort -u)
[ "$versions" = 17 ] || fail "the pipeline sets up Java '$(echo $versions)', not Java 17 alone"
if grep -qE 'JAVA_HOME_8|JAVA8_HOME|JAVA_HOME_11|JAVA_HOME_21' "$WORKFLOW"; then
  fail "the pipeline still points a step at another JDK: $(grep -nE 'JAVA_HOME_8|JAVA8_HOME|JAVA_HOME_11|JAVA_HOME_21' "$WORKFLOW" | head -3)"
fi
if echo "$block" | grep -qE '^[[:space:]]+continue-on-error:[[:space:]]*true'; then
  fail "job $job is allowed to fail (continue-on-error: true)"
fi
name=$(echo "$block" | sed -nE 's/^    name:[[:space:]]*(.*)$/\1/p' | head -1 | sed -E "s/^['\"]//; s/['\"]$//")
[ "$name" = "JDK 17" ] || fail "job $job is named '$name', not 'JDK 17'"
echo "pipeline: one job, $job, named '$name', on Java 17, must pass"

[ "$(java_major)" = 17 ] || fail "this job runs java $(java_major), not 17"
for m in common spark-job workflow-app; do
  [ -d "$m/target/classes" ] || fail "$m was not built in this job"
done
require_module_green common 30
require_module_green spark-job 8
require_module_green workflow-app 30

base=$(merge_base)
changed=$(git diff --name-status --diff-filter=MDRT "$base" HEAD -- ':(glob)**/src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "existing test sources changed since $(git rev-parse --short "$base")"
fi
pass "AC1 one Java 17 job ('$name'), must pass; every module's tests pass on JDK 17, none skipped, tests unchanged"
