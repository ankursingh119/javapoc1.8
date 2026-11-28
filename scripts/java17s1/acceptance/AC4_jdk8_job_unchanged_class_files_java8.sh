#!/usr/bin/env bash
# AC4 The Java 8 job is unchanged and passes; class files stay Java 8.
# Static part, run in the JDK 17 job after the build: the jdk8 job in .github/workflows/ci.yml is line for line the
# same as at the merge base with origin/main, and every .class file under common, spark-job and workflow-app's
# target/classes has major version 52 (Java 8), Scala's included. That the JDK 8 job passes is read from the
# pipeline's run on the pull request, not here. Card SBJ17-16 only: slice 2 retires the JDK 8 job.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17s1/acceptance/lib.sh

WORKFLOW=.github/workflows/ci.yml
base=$(merge_base)
before=$(git show "$base:$WORKFLOW" | job_block_of jdk8)
after=$(job_block_of jdk8 < "$WORKFLOW")
[ -n "$after" ] || fail "the jdk8 job is missing from $WORKFLOW"
if [ "$before" != "$after" ]; then
  diff <(echo "$before") <(echo "$after") >&2 || true
  fail "the jdk8 job changed since $(git rev-parse --short "$base")"
fi

n=0
for m in common spark-job workflow-app; do
  d="$m/target/classes"
  [ -d "$d" ] || fail "$d is missing (build first)"
  while IFS= read -r -d '' f; do
    v=$(class_major "$f")
    [ "$v" = 52 ] || fail "$f has class-file version $v, not 52 (Java 8)"
    n=$((n + 1))
  done < <(find "$d" -name '*.class' -print0)
done
[ "$n" -gt 0 ] || fail "no class files found"
pass "AC4 the jdk8 job is unchanged since $(git rev-parse --short "$base") and all $n class files are Java 8 (52)"
