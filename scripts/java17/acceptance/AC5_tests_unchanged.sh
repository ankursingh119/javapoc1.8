#!/usr/bin/env bash
# AC5 No existing test and no test source file is changed. Any red run of a timing or ordering test (risks SBJ17-5,
# SBJ17-7) is named in the card file with how it was handled, without editing the test.
# Fails when any file under a module's src/test differs from the merge base with origin/main (added, changed,
# deleted or renamed). The second sentence is observed, not tested: the card file names each red run.
# Card SBJ17-9 only: later cards may add tests.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

base=$(merge_base)
changed=$(git diff --name-status "$base" HEAD -- '*/src/test/**' 'src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "test sources changed since $base"
fi
pass "AC5 no test source changed since $(git rev-parse --short "$base")"
