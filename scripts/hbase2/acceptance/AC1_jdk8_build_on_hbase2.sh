#!/usr/bin/env bash
# AC1 In the pipeline's JDK 8 job, `mvn -B install` and `mvn -B test` pass with common and spark-job on an HBase 2
# client and the pipeline's HBase container on HBase 2; the existing tests are unchanged and pass, and the new tests
# pass.
# Runs in the JDK 8 job after `mvn -B install` and `mvn -B test` (a red Maven step stops the job before this check,
# so a pass here also means both passed). Checks: the running java is 8; common and spark-job resolve hbase.version
# 2.x; the HBase server in the pipeline's container reports 2.x; no existing file under any src/test changed, was
# deleted or renamed since the merge base with origin/main (new files are allowed); every module passes at least the
# tests it had before (common 30, spark-job 8, workflow-app 30), none skipped, and the HBase end-to-end test ran
# against the container. This card's new tests are these scripts (scripts/hbase2/acceptance), run by the workflow.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

[ "$(java_major)" = 8 ] || fail "this job runs java $(java_major), not 8"

for m in common spark-job; do
  v=$(module_prop "$m" hbase.version)
  [[ "$v" =~ ^2\.[0-9]+\.[0-9]+$ ]] || fail "$m builds on HBase client '$v', not 2.x"
  echo "$m: HBase client $v"
done

server=$(hbase_server_version)
[[ "$server" =~ ^2\. ]] || fail "the pipeline's HBase server reports version '${server:-none}', not 2.x"
echo "HBase server: $server"

base=$(merge_base)
changed=$(git diff --name-status --diff-filter=MDRT "$base" HEAD -- '*/src/test/**' 'src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "existing test sources changed since $base (only new test files are allowed)"
fi

require_module_green common 30
require_module_green spark-job 8
require_module_green workflow-app 30
require_clean_report "$HBASE_E2E_REPORT"
pass "AC1 JDK 8 build on the HBase $v client against HBase server $server: existing tests unchanged and passing"
