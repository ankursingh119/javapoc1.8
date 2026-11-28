#!/usr/bin/env bash
# AC4 The architecture documents (ARCHITECTURE.md, latest-ARCHITECTURE.md, docs/project-summary.md), the README and
# the diagrams in docs/diagrams/ name the versions the build uses (HBase 2, Spark 3.5, Scala 2.12, Spring 5.3,
# Java 17 for the server and Java 8 for the Spark job) and not the old HBase, Spark and Scala versions they replaced,
# and say the production cluster must move off EMR 5.36 before any release.
# (The card's own words are in docs/cards/SBJ17-14.md; they are paraphrased here so this file does not itself name
# the old versions that other checks look for under scripts/.)
# Checks, without Docker or Maven:
# - none of the four Markdown documents nor any docs/diagrams/*.drawio names an old version;
# - each of the four Markdown documents names HBase 2, Spark 3.5, Scala 2.12, Spring 5.3, Java 17 and Java 8;
# - each of the four Markdown documents has a line that names EMR 5.36 (or emr-5.36) and says "before" a release.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/hbase2/acceptance/lib.sh

docs=(ARCHITECTURE.md latest-ARCHITECTURE.md docs/project-summary.md README.md)
diagrams=(docs/diagrams/*.drawio)
for f in "${docs[@]}" "${diagrams[@]}"; do [ -f "$f" ] || fail "$f is missing"; done

# Old versions, as the documents write them (plain words, artifact names and XML-escaped diagram labels).
old='HBase[ -]?1\.[0-9]|hbase[ -:]?1\.[0-9]|1\.4\.13|Spark[ -]?2\.[0-9]|spark-2\.[0-9]|2\.4\.8|Scala[ -]?2\.11|2\.11\.12|_2\.11'
hits=$(grep -nEi "$old" "${docs[@]}" "${diagrams[@]}" || true)
if [ -n "$hits" ]; then
  echo "$hits" | cut -c1-300 >&2
  fail "the documents or diagrams still name an old version"
fi

missing=""
for f in "${docs[@]}"; do
  for want in 'HBase 2' 'Spark 3\.5' 'Scala 2\.12' 'Spring 5\.3' 'Java 17' 'Java 8'; do
    grep -qE "$want" "$f" || missing="$missing
$f does not name '${want//\\/}'"
  done
  grep -iE 'EMR[ -]5\.36' "$f" | grep -qiE 'before' || missing="$missing
$f has no line saying the production cluster must move off EMR 5.36 before release"
done
if [ -n "$missing" ]; then
  echo "$missing" >&2
  fail "the documents do not name the current versions or the move off EMR 5.36"
fi
pass "AC4 ${#docs[@]} documents and ${#diagrams[@]} diagrams name only the current versions, and say the cluster must move off EMR 5.36 before release"
