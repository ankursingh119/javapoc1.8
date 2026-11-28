#!/usr/bin/env bash
# AC3 common's class files target the project's Java; a check in the pipeline reads their class-file version.
# Card SBJ17-9 required Java 8 (major 52) while spark-job ran on JDK 8. Card SBJ17-17 (docs/cards/SBJ17-17.md) moved
# the whole build to Java 17, so this guard now requires major 61 (it was AC3_common_targets_java8.sh).
# Every .class under common/target/classes must have class-file major version 61 (Java 17). Runs after the build.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

dir=common/target/classes
n=0; bad=0
while IFS= read -r -d '' f; do
  major=$(od -An -tu1 -j6 -N2 "$f" | awk '{print $1 * 256 + $2}')
  n=$((n + 1))
  if [ "$major" != 61 ]; then
    echo "  $f: major version $major" >&2
    bad=$((bad + 1))
  fi
done < <(find "$dir" -name '*.class' -print0 2>/dev/null)
[ "$n" -gt 0 ] || fail "no class files under $dir (build common first)"
[ "$bad" -eq 0 ] || fail "$bad of $n class files under $dir do not target Java 17 (major 61)"
pass "AC3 all $n class files of common target Java 17 (major 61)"
