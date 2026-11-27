#!/usr/bin/env bash
# Shared helpers for card SBJ17-9's acceptance checks (docs/cards/SBJ17-9.md). Sourced, not run.
# The checks run from the repository root.

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# The branch this card started from; the checks that compare with it need the full history (fetch-depth: 0).
BASE_REF=${BASE_REF:-origin/main}
merge_base() {
  git rev-parse --verify -q "$BASE_REF" > /dev/null || fail "$BASE_REF is not fetched (checkout needs fetch-depth: 0)"
  git merge-base "$BASE_REF" HEAD
}

# The Spring version the build resolves (the parent pom's spring.version, as Maven sees it).
spring_version() {
  mvn -B -q -N help:evaluate -Dexpression=spring.version -DforceStdout 2>/dev/null | tr -d '\r' | tail -1
}

require_spring_53() {
  local v
  v=$(spring_version)
  [[ "$v" =~ ^5\.3\.[0-9]+ ]] || fail "the build resolves Spring '$v', not 5.3.x"
  echo "Spring $v"
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
  [ "$t" -ge "$min" ] || fail "$module ran $t tests, fewer than the $min it had before the change"
  [ "$fl" -eq 0 ] && [ "$e" -eq 0 ] || fail "$module: $fl failed and $e errors of $t"
  [ "$s" -eq 0 ] || fail "$module: $s tests skipped"
  echo "$module: $t of $t pass"
}
