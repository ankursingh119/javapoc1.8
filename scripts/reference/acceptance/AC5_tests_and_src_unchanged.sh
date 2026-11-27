#!/usr/bin/env bash
# AC5 Nothing under src/ and no existing test is changed, and the existing tests pass.
# Diffs every path under a src/ folder (main code and tests) between the merge base with origin/main and HEAD.
# That the existing tests pass is the pipeline's own `mvn -B test` step in the same job.
# Card-specific: the pipeline runs it only on this card's branch and pull request.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/reference/acceptance/lib.sh

git rev-parse --verify -q origin/main > /dev/null || fail "origin/main is not fetched"
base=$(git merge-base origin/main HEAD) || fail "no merge base with origin/main"
changed=$(git diff --name-only "$base" HEAD -- ':(glob)**/src/**' 'src/**')
[ -z "$changed" ] || { echo "$changed"; fail "files under src/ changed since $base"; }
pass "AC5 nothing under src/ changed since $(git rev-parse --short "$base")"
