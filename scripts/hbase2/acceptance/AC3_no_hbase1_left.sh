#!/usr/bin/env bash
# AC3 No HBase 1.x artifact is in any module's build or in the spark-job jar, and the HBase server the pipeline
# starts reports a 2.x version.
# Runs in the JDK 8 job after `mvn -B install` (the spark-job jar must exist). Checks:
# - `mvn dependency:list` over the whole reactor: every org.apache.hbase artifact is 2.x, and common and spark-job
#   each have at least one;
# - the spark-job jar: every bundled org.apache.hbase artifact (META-INF/maven/org.apache.hbase/*/pom.properties)
#   is 2.x, and hbase-client is among them;
# - the HBase server in the pipeline's container reports 2.x.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

out=target/hbase2-ac3
mkdir -p "$out"
mvn -B -q dependency:list -DincludeGroupIds=org.apache.hbase -DoutputFile=target/hbase-deps.txt -DappendOutput=false \
  > "$out/dependency-list.log" 2>&1 || { tail -50 "$out/dependency-list.log" >&2; fail "mvn dependency:list failed"; }

for m in common spark-job workflow-app; do
  f=$m/target/hbase-deps.txt
  [ -f "$f" ] || fail "$f was not written by dependency:list"
  deps=$(tr -d '\r' < "$f" | grep -oE 'org\.apache\.hbase(\.thirdparty)?:[^: ]+:[^: ]+:[^: ]+' || true)
  old=$(echo "$deps" | grep -E '^org\.apache\.hbase:[^:]+:[^:]+:1\.' || true)
  [ -z "$old" ] || { echo "$old" >&2; fail "$m's build has HBase 1.x artifacts"; }
  case "$m" in
    common|spark-job)
      echo "$deps" | grep -qE '^org\.apache\.hbase:[^:]+:[^:]+:2\.' || fail "$m's build has no HBase 2.x artifact"
      ;;
  esac
  echo "$m: $(echo "$deps" | grep -cE '^org\.apache\.hbase:' || true) HBase artifacts, none 1.x"
done

[ -f "$JOB_JAR" ] || fail "$JOB_JAR is missing (run mvn install first)"
props=$(unzip -Z1 "$JOB_JAR" | grep -E '^META-INF/maven/org\.apache\.hbase/[^/]+/pom\.properties$' || true)
[ -n "$props" ] || fail "$JOB_JAR bundles no org.apache.hbase artifact"
client=no
while read -r p; do
  a=$(echo "$p" | cut -d/ -f4)
  v=$(unzip -p "$JOB_JAR" "$p" | tr -d '\r' | sed -nE 's/^version=//p')
  [[ "$v" =~ ^2\. ]] || fail "$JOB_JAR bundles $a $v, not 2.x"
  [ "$a" = hbase-client ] && client=yes
  echo "jar: $a $v"
done <<< "$props"
[ "$client" = yes ] || fail "$JOB_JAR does not bundle hbase-client"

server=$(hbase_server_version)
[[ "$server" =~ ^2\. ]] || fail "the pipeline's HBase server reports version '${server:-none}', not 2.x"
pass "AC3 no HBase 1.x in any module's build or the spark-job jar; the HBase server reports $server"
