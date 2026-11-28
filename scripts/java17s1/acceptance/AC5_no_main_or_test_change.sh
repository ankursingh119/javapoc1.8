#!/usr/bin/env bash
# AC5 No main source file or existing test changes.
# Fails when any file under a module's src/main or src/test differs from the merge base with origin/main (added,
# changed, deleted or renamed). Card SBJ17-16 only: later cards may change sources.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17s1/acceptance/lib.sh

base=$(merge_base)
changed=$(git diff --name-status "$base" HEAD -- ':(glob)**/src/main/**' ':(glob)**/src/test/**')
if [ -n "$changed" ]; then
  echo "$changed" >&2
  fail "main or test sources changed since $(git rev-parse --short "$base")"
fi
pass "AC5 no main or test source changed since $(git rev-parse --short "$base")"
