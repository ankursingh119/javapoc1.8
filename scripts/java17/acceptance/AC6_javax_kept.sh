#!/usr/bin/env bash
# AC6 The javax namespace is kept: a check in the pipeline fails if any file under common, workflow-app or the poms
# mentions a jakarta.* package, a Jakarta EE 9+ artifact (jakarta.*:*-api at version 3 or later, Jetty 11 or later,
# Spring 6) or a Spring version other than 5.3.x, and confirms the javax.servlet imports the existing tests use are
# still present and unchanged.
# Any mention of "jakarta" in common/, workflow-app/ or a pom fails (it covers the packages and every jakarta
# artifact); the build must resolve Spring 5.3.x and Jetty 9.x; the javax.servlet imports under */src/test must
# equal those at the merge base with origin/main, and the production server must still import
# javax.servlet.MultipartConfigElement. A lasting guard for this programme's hard rule: a later card that moves to
# Jakarta EE changes it on purpose.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

hits=$(git grep -n -i 'jakarta' -- common workflow-app pom.xml '*/pom.xml' || true)
if [ -n "$hits" ]; then
  echo "$hits" >&2
  fail "jakarta is mentioned under common, workflow-app or a pom"
fi

require_spring_53
jetty=$(mvn -B -q -N help:evaluate -Dexpression=jetty.version -DforceStdout 2>/dev/null | tr -d '\r' | tail -1)
[[ "$jetty" =~ ^9\. ]] || fail "the build resolves Jetty '$jetty', not 9.x"
echo "Jetty $jetty"

base=$(merge_base)
now=$(git grep -h 'import javax\.servlet' HEAD -- '*/src/test/*' | sort)
before=$(git grep -h 'import javax\.servlet' "$base" -- '*/src/test/*' | sort)
[ -n "$before" ] || fail "no javax.servlet imports in the test sources at $base: the check would prove nothing"
if [ "$now" != "$before" ]; then
  diff <(echo "$before") <(echo "$now") >&2 || true
  fail "the javax.servlet imports of the test sources changed since $base (< before, > now)"
fi
git grep -q 'import javax\.servlet\.MultipartConfigElement;' HEAD -- workflow-app/src/main/java/com/example/salesbatch/workflow/WorkflowServer.java \
  || fail "WorkflowServer no longer imports javax.servlet.MultipartConfigElement"
pass "AC6 javax kept: no jakarta, Spring 5.3.x, Jetty 9.x, $(echo "$now" | wc -l) javax.servlet test imports unchanged"
