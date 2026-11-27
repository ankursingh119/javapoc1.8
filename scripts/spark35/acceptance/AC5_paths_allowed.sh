#!/usr/bin/env bash
# AC5 Nothing under any src/main changes except one setting in SalesAggregator.scala that keeps Spark reading HBase
# regions it sizes at zero (spark.hadoopRDD.ignoreEmptySplits=false), and the change touches only build files,
# docker/, scripts/, .github/workflows/, the README, new tests and docs/cards/.
# Compared with the merge base with origin/main:
# - the only file changed under any src/main is SalesAggregator.scala, and it carries the setting;
# - in that file, the added lines with the setting `.set("spark.hadoopRDD.ignoreEmptySplits", "false")` taken out
#   equal the removed lines (spaces ignored): the setting is the whole change, added as its own line or on the
#   existing SparkConf;
# - every other changed file is a pom.xml, under docker/, scripts/, .github/workflows/ or docs/cards/, README.md,
#   or a new file (status A) under a src/test.
# Card SBJ17-11 only (its branch and pull request).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/spark35/acceptance/lib.sh

base=$(merge_base)

grep -qE "$SETTING_RE" "$JOB_SOURCE" || fail "$JOB_SOURCE does not set spark.hadoopRDD.ignoreEmptySplits to false"

main_changed=$(git diff --name-only "$base" HEAD -- '*/src/main/**' 'src/main/**')
other_main=$(echo "$main_changed" | grep -vxF "$JOB_SOURCE" | grep -v '^$' || true)
[ -z "$other_main" ] || fail "src/main files other than $JOB_SOURCE changed: $other_main"

norm() { sed -E "s/$SETTING_RE//" | tr -d ' \t\r\n'; }
added=$(git diff -U0 "$base" HEAD -- "$JOB_SOURCE" | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' | norm)
removed=$(git diff -U0 "$base" HEAD -- "$JOB_SOURCE" | grep -E '^-' | grep -vE '^---' | sed 's/^-//' | norm)
[ "$added" = "$removed" ] || {
  git diff "$base" HEAD -- "$JOB_SOURCE" >&2
  fail "$JOB_SOURCE changes more than the one setting"
}

outside=$(git diff --name-status "$base" HEAD | awk -F'\t' '{print $1"\t"$NF}' | while IFS=$'\t' read -r st path; do
  case "$path" in
    "$JOB_SOURCE"|pom.xml|*/pom.xml|docker/*|scripts/*|.github/workflows/*|docs/cards/*|README.md) ;;
    */src/test/*|src/test/*) [ "$st" = A ] || echo "$st $path" ;;
    *) echo "$st $path" ;;
  esac
done)
if [ -n "$outside" ]; then
  echo "$outside" >&2
  fail "files changed outside the allowed paths since $base"
fi
pass "AC5 src/main changes only by the one setting, and every changed file lies in the allowed paths ($(git diff --name-only "$base" HEAD | wc -l) files)"
