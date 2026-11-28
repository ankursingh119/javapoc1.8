#!/usr/bin/env bash
# AC5 Nothing under any `src/main` changes, and the change touches only build files, `docker/`, `scripts/`,
# `.github/workflows/`, the README, the documents named in AC4, new tests and `docs/cards/`.
# Compared with the merge base with origin/main: no file under any src/main changed; every changed file is a pom.xml,
# under docker/, scripts/, .github/workflows/, docs/cards/ or docs/diagrams/, README.md, ARCHITECTURE.md,
# latest-ARCHITECTURE.md or docs/project-summary.md, or a new file (status A) under a src/test.
# Card SBJ17-14 only (its branch and pull request).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

base=$(merge_base)

main_changed=$(git diff --name-only "$base" HEAD -- '*/src/main/**' 'src/main/**')
[ -z "$main_changed" ] || fail "files under src/main changed: $main_changed"

outside=$(git diff --name-status "$base" HEAD | awk -F'\t' '{print $1"\t"$NF}' | while IFS=$'\t' read -r st path; do
  case "$path" in
    pom.xml|*/pom.xml|docker/*|scripts/*|.github/workflows/*|docs/cards/*|docs/diagrams/*) ;;
    README.md|ARCHITECTURE.md|latest-ARCHITECTURE.md|docs/project-summary.md) ;;
    */src/test/*|src/test/*) [ "${st:0:1}" = A ] || echo "$st $path" ;;
    *) echo "$st $path" ;;
  esac
done)
if [ -n "$outside" ]; then
  echo "$outside" >&2
  fail "files changed outside the allowed paths since $base"
fi
pass "AC5 nothing under src/main changed, and every changed file lies in the allowed paths ($(git diff --name-only "$base" HEAD | wc -l) files)"
