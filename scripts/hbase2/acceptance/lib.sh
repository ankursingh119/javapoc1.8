#!/usr/bin/env bash
# Shared helpers for card SBJ17-14's acceptance checks (docs/cards/SBJ17-14.md). Sourced, not run.
# The checks run from the repository root.

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# The branch this card started from; the checks that compare with it need the full history (fetch-depth: 0).
BASE_REF=${BASE_REF:-origin/main}
merge_base() {
  git rev-parse --verify -q "$BASE_REF" > /dev/null || fail "$BASE_REF is not fetched (checkout needs fetch-depth: 0)"
  git merge-base "$BASE_REF" HEAD
}

# A property as Maven resolves it for one module.
module_prop() {
  mvn -B -q -pl "$1" help:evaluate -Dexpression="$2" -DforceStdout 2>/dev/null | tr -d '\r' | tail -1
}

# Major version of the running java: 8 for 1.8.x, else the first number.
java_major() {
  local v
  v=$(java -version 2>&1 | sed -nE 's/.*version "([^"]+)".*/\1/p' | head -1)
  case "$v" in 1.*) echo "${v#1.}" | cut -d. -f1 ;; *) echo "$v" | cut -d. -f1 ;; esac
}

# Sum of tests, failures, errors and skipped over a module's surefire reports: "tests failures errors skipped".
surefire_totals() {
  local dir="$1/target/surefire-reports" f t=0 fl=0 e=0 s=0 a
  ls "$dir"/TEST-*.xml > /dev/null 2>&1 || { echo "0 0 0 0"; return; }
  for f in "$dir"/TEST-*.xml; do
    a=$(grep -m1 -o '<testsuite [^>]*' "$f")
    t=$((t + $(printf '%s' "$a" | sed -nE 's/.* tests="([0-9]+)".*/\1/p')))
    fl=$((fl + $(printf '%s' "$a" | sed -nE 's/.* failures="([0-9]+)".*/\1/p')))
    e=$((e + $(printf '%s' "$a" | sed -nE 's/.* errors="([0-9]+)".*/\1/p')))
    s=$((s + $(printf '%s' "$a" | sed -nE 's/.* skipped="([0-9]+)".*/\1/p')))
  done
  echo "$t $fl $e $s"
}

# Fail unless a module ran at least MIN tests with no failure, error or skip.
require_module_green() {
  local module=$1 min=$2 t fl e s
  read -r t fl e s < <(surefire_totals "$module")
  [ "$t" -ge "$min" ] || fail "$module ran $t tests, fewer than the $min expected"
  [ "$fl" -eq 0 ] && [ "$e" -eq 0 ] || fail "$module: $fl failed and $e errors of $t"
  [ "$s" -eq 0 ] || fail "$module: $s tests skipped"
  echo "$module: $t of $t pass"
}

# Fail unless one test class's surefire report exists and ran at least one test with no failure, error or skip.
require_clean_report() {
  local f=$1 a t fl e s
  [ -f "$f" ] || fail "$f is missing (the test did not run)"
  a=$(grep -m1 -o '<testsuite [^>]*' "$f")
  t=$(printf '%s' "$a" | sed -nE 's/.* tests="([0-9]+)".*/\1/p')
  fl=$(printf '%s' "$a" | sed -nE 's/.* failures="([0-9]+)".*/\1/p')
  e=$(printf '%s' "$a" | sed -nE 's/.* errors="([0-9]+)".*/\1/p')
  s=$(printf '%s' "$a" | sed -nE 's/.* skipped="([0-9]+)".*/\1/p')
  [ "$t" -gt 0 ] || fail "$f ran no tests"
  [ "$fl" -eq 0 ] && [ "$e" -eq 0 ] || fail "$f: $fl failed and $e errors of $t"
  [ "$s" -eq 0 ] || fail "$f: $s of $t skipped"
}

# The HBase container docker/local/docker-compose.yml starts, and the version its running master reports
# (`status 'detailed'` asks the cluster, so this is the server's version, not only the shell's library).
HBASE_CONTAINER=sales-hbase
hbase_server_version() {
  echo "status 'detailed'" | docker exec -i "$HBASE_CONTAINER" /hbase/bin/hbase shell -n 2>/dev/null \
    | tr -d '\r' | sed -nE 's/^version ([0-9][0-9.]*).*/\1/p' | head -1
}

# The test that runs the Spark job against the real HBase container (skips when HBase is down).
HBASE_E2E_REPORT=spark-job/target/surefire-reports/TEST-com.example.salesbatch.spark.SalesAggregatorHBaseTest.xml

# The spark-job jar (shaded, bundles the HBase client).
JOB_JAR=spark-job/target/spark-job-1.0.0-SNAPSHOT.jar
