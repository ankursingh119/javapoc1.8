#!/usr/bin/env bash
# AC6 No main source change.
# Fails when any file under a module's src/main differs from the merge base with origin/main (added, changed,
# deleted or renamed). Existing tests unchanged is AC1's.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

base=$(merge_base)
changed=$(git diff --name-status "$base" HEAD -- ':(glob)**/src/main/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "main sources changed since $(git rev-parse --short "$base")"
fi
pass "AC6 no main source file changed since $(git rev-parse --short "$base")"
