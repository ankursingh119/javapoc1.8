#!/usr/bin/env bash
# AC7 The change is one pull request from this branch; nothing outside common/, workflow-app/, the poms,
# .github/workflows/, scripts/, .vscode/, README.md and docs/cards/ changes (never ui/, sample-data/ or
# docs/reference/).
# Fails when a file changed since the merge base with origin/main lies outside those paths. "One pull request" is
# observed on the card (its link). Card SBJ17-9 only.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17/acceptance/lib.sh

base=$(merge_base)
outside=$(git diff --name-only "$base" HEAD | grep -vE '^(common/|workflow-app/|\.github/workflows/|scripts/|\.vscode/|docs/cards/|README\.md$|pom\.xml$|spark-job/pom\.xml$)' || true)
if [ -n "$outside" ]; then
  echo "$outside" >&2
  fail "files changed outside the allowed paths since $base"
fi
pass "AC7 every changed file lies in the allowed paths ($(git diff --name-only "$base" HEAD | wc -l) files)"
