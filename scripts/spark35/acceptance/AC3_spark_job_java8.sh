#!/usr/bin/env bash
# AC3 spark-job's class files are Java 8 class files and its tests run on JDK 8.
# Runs in the JDK 8 job after `mvn -B test`. Every .class under spark-job/target/classes and
# spark-job/target/test-classes has class-file major version 52 (Java 8), and every spark-job surefire report
# records java.specification.version 1.8 (the JVM the tests ran on).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/spark35/acceptance/lib.sh

n=0; bad=0
for dir in spark-job/target/classes spark-job/target/test-classes; do
  while IFS= read -r -d '' f; do
    major=$(od -An -tu1 -j6 -N2 "$f" | awk '{print $1 * 256 + $2}')
    n=$((n + 1))
    if [ "$major" != 52 ]; then
      echo "  $f: major version $major" >&2
      bad=$((bad + 1))
    fi
  done < <(find "$dir" -name '*.class' -print0 2>/dev/null)
done
[ "$n" -gt 0 ] || fail "no class files under spark-job/target (build spark-job first)"
[ "$bad" -eq 0 ] || fail "$bad of $n spark-job class files do not target Java 8 (major 52)"

reports=0
for f in spark-job/target/surefire-reports/TEST-*.xml; do
  [ -f "$f" ] || continue
  reports=$((reports + 1))
  grep -qE '<property name="java\.specification\.version" value="1\.8"' "$f" \
    || fail "$f did not run on JDK 8 ($(grep -oE 'name="java\.specification\.version" value="[^"]*"' "$f" | head -1))"
done
[ "$reports" -gt 0 ] || fail "spark-job has no surefire reports (run mvn -B test first)"
pass "AC3 all $n spark-job class files target Java 8 (major 52), and its $reports test classes ran on JDK 8"
