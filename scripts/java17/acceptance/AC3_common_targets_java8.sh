#!/usr/bin/env bash
# AC3 common's class files still target Java 8; a check in the pipeline reads their class-file version.
# Every .class under common/target/classes must have class-file major version 52 (Java 8): spark-job, still on
# JDK 8 (on Spark 3.5.5 and Scala 2.12 since card SBJ17-11), loads them. Runs in both jobs after the build.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

dir=common/target/classes
n=0; bad=0
while IFS= read -r -d '' f; do
  major=$(od -An -tu1 -j6 -N2 "$f" | awk '{print $1 * 256 + $2}')
  n=$((n + 1))
  if [ "$major" != 52 ]; then
    echo "  $f: major version $major" >&2
    bad=$((bad + 1))
  fi
done < <(find "$dir" -name '*.class' -print0 2>/dev/null)
[ "$n" -gt 0 ] || fail "no class files under $dir (build common first)"
[ "$bad" -eq 0 ] || fail "$bad of $n class files under $dir do not target Java 8 (major 52)"
pass "AC3 all $n class files of common target Java 8 (major 52)"
