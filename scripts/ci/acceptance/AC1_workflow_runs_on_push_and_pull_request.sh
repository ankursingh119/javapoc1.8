#!/usr/bin/env bash
# AC1 A GitHub Actions workflow runs on every push and on every pull request, on `ubuntu-latest`.
# Static check of .github/workflows/ci.yml. The pipeline's own runs on the pull request are the other half of the proof.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

require_workflow
on=$(on_block)
echo "$on" | grep -qE '^  push:' || fail "the workflow does not run on push"
echo "$on" | grep -qE '^  pull_request:' || fail "the workflow does not run on pull_request"
# "every push": no branch, tag or path filter may narrow the push trigger.
if echo "$on" | awk '/^  push:/ { p = 1; next } /^  [a-z_]+:/ { p = 0 } p' | grep -qE '^    (branches|branches-ignore|tags|tags-ignore|paths|paths-ignore):'; then
  fail "the push trigger is filtered, so not every push runs it"
fi
if echo "$on" | awk '/^  pull_request:/ { p = 1; next } /^  [a-z_]+:/ { p = 0 } p' | grep -qE '^    (branches|branches-ignore|paths|paths-ignore):'; then
  fail "the pull_request trigger is filtered, so not every pull request runs it"
fi
for job in jdk8 jdk17; do
  block=$(job_block "$job")
  [ -n "$block" ] || fail "job $job is missing"
  echo "$block" | grep -qE '^    runs-on: ubuntu-latest[[:space:]]*$' || fail "job $job does not run on ubuntu-latest"
done
pass "AC1 the workflow runs on every push and pull request, both jobs on ubuntu-latest"
