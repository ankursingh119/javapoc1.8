#!/usr/bin/env bash
# Verify sensitivity of AC3's check, on a fresh clone at the PR head. Expected: head on JDK 8 PASS, both mutants FAIL.
set -u
R="D:/Genpact Sample/javapoc_programme/.prime/tmp/SBJ17-11/verify/m3"
HEAD_SHA=3c465dbd6de72a45ba9f9ee89507128b41efa098
J8="C:/Program Files/Eclipse Adoptium/jdk-8.0.504.1-hotspot"
J17="C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot"
export SPARK_LOCAL_IP=127.0.0.1
[ -d "$R" ] || git clone -q https://github.com/ankursingh119/javapoc1.8.git "$R"
cd "$R"
git -c advice.detachedHead=false checkout -q -f "$HEAD_SHA"
build() { JAVA_HOME="$1" PATH="$1/bin:$PATH" mvn -B -q -pl common,spark-job -am clean test $2 > "../m3-$3.log" 2>&1; echo "  mvn exit $?"; }
check() { bash scripts/spark35/acceptance/AC3_spark_job_java8.sh 2>&1 | grep -E '^(PASS|FAIL)'; }
echo "== head, built and tested on JDK 8"; build "$J8" "" head; check
echo "== mutant a: built and tested on JDK 17 (class target unchanged)"; build "$J17" "" jdk17; check
echo "== mutant b: scalac -target:11, built on JDK 17, tests skipped"
sed -i 's#<arg>-target:jvm-1.8</arg>#<arg>-target:11</arg>#' spark-job/pom.xml
build "$J17" "-DskipTests" target11; check
git checkout -q -- spark-job/pom.xml
