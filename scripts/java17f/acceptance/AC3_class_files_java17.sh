#!/usr/bin/env bash
# AC3 Class files Java 17.
# Runs in the Java 17 job after the build and tests. Every .class under target/classes and target/test-classes of
# common, spark-job and workflow-app (Java and Scala alike) has class-file major version 61 (Java 17), and each
# module has some.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

total=0; bad=0
for m in common spark-job workflow-app; do
  n=0
  for dir in "$m/target/classes" "$m/target/test-classes"; do
    while IFS= read -r -d '' f; do
      major=$(class_major "$f")
      n=$((n + 1))
      if [ "$major" != 61 ]; then
        [ "$bad" -lt 10 ] && echo "  $f: major version $major" >&2
        bad=$((bad + 1))
      fi
    done < <(find "$dir" -name '*.class' -print0 2>/dev/null)
  done
  [ "$n" -gt 0 ] || fail "no class files under $m/target (build $m first)"
  echo "$m: $n class files"
  total=$((total + n))
done
[ "$bad" -eq 0 ] || fail "$bad of $total class files are not Java 17 class files (major 61)"
pass "AC3 all $total class files of common, spark-job and workflow-app are Java 17 class files (major 61)"
