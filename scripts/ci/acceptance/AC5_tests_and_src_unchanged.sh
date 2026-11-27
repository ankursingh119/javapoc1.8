#!/usr/bin/env bash
# AC5 The existing tests and the code under `src/` are unchanged.
# Diffs every path under a src/ folder (main code and tests) between the merge base with origin/main and HEAD.
# Needs the history of origin/main (the pipeline checks out with fetch-depth: 0).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/ci/acceptance/lib.sh

git rev-parse --verify -q origin/main >/dev/null || fail "origin/main is not fetched"
base=$(git merge-base origin/main HEAD) || fail "no merge base with origin/main"
changed=$(git diff --name-only "$base" HEAD -- ':(glob)**/src/**' 'src/**')
[ -z "$changed" ] || { echo "$changed"; fail "files under src/ changed since $base"; }
pass "AC5 nothing under src/ changed since $(git rev-parse --short "$base")"
