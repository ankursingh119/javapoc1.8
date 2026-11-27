#!/usr/bin/env bash
# Verify sensitivity of AC5's check on a fresh clone at the PR head: each mutant is one commit on top of the head,
# reset after. Expected: head PASS, every mutant FAIL.
set -u
R="D:/Genpact Sample/javapoc_programme/.prime/tmp/SBJ17-11/verify/m5"
HEAD_SHA=3c465dbd6de72a45ba9f9ee89507128b41efa098
[ -d "$R" ] || git clone -q https://github.com/ankursingh119/javapoc1.8.git "$R"
cd "$R"
git -c advice.detachedHead=false checkout -q -f "$HEAD_SHA"
run() { echo "== $1"; bash scripts/spark35/acceptance/AC5_paths_allowed.sh 2>&1 | grep -E '^(PASS|FAIL)'; }
mut() { git -c user.name=v -c user.email=v@v commit -qam "$1" ; run "$1"; git reset -q --hard "$HEAD_SHA"; }
run "head unchanged"
echo "// mutant" >> common/src/main/java/$(cd common/src/main/java && find . -name '*.java' | head -1 | sed 's#^\./##'); mut "another src/main file changed"
echo "mutant" >> ARCHITECTURE.md; mut "ARCHITECTURE.md changed (outside the allowed paths)"
f=$(git ls-files 'spark-job/src/test/*' | grep -v AC2Small | head -1); echo "// mutant" >> "$f"; mut "an existing test edited ($f)"
sed -i 's/\(setAppName("SalesAggregator-" + date)\)/\1.set("spark.ui.enabled", "false")/' spark-job/src/main/scala/com/example/salesbatch/spark/SalesAggregator.scala; mut "a second setting added in SalesAggregator.scala"
sed -i 's/"spark.hadoopRDD.ignoreEmptySplits", "false"/"spark.hadoopRDD.ignoreEmptySplits", "true"/' spark-job/src/main/scala/com/example/salesbatch/spark/SalesAggregator.scala; mut "the setting flipped to true"
