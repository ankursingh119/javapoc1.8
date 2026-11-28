#!/usr/bin/env bash
# Verify, SBJ17-16: sensitivity mutants, run inside sbj1716-new (the PR head built as its JDK 17 job builds it).
#   mutants.sh static     no HBase needed: AC4 (class files) and AC5
#   mutants.sh hbase      HBase up (network host): AC1 (two build mutants) and AC2 (three mutants)
# Each mutant runs in a fresh copy of /work; prints "MUTANT <name> <check> -> KILLED|SURVIVED" from the check's exit.
set -uo pipefail
export BASE_REF=33e45df7dc7ea249233641cab5c8429f4772ad53
# The clone was made on Windows (core.autocrlf=true): restore the committed line endings before any check reads files.
fresh() { rm -rf /m; cp -a /work /m; cd /m; git config --global --add safe.directory '*'; git config core.autocrlf false
  git ls-files -z -- '*.yml' '*.xml' '*.java' '*.scala' '*.sh' | xargs -0 rm -f; git checkout -q -- .; }
verdict() { # name check rc
  if [ "$3" -ne 0 ]; then echo "MUTANT $1 $2 -> KILLED"; else echo "MUTANT $1 $2 -> SURVIVED"; fi
}
baseline() { # check
  bash "$1" > /tmp/base.log 2>&1; local rc=$?
  echo "BASELINE $1 rc=$rc $(grep -E 'PASS|FAIL' /tmp/base.log | tail -1)"
}
case "$1" in
static)
  fresh; baseline scripts/java17s1/acceptance/AC4_jdk8_job_unchanged_class_files_java8.sh
  baseline scripts/java17s1/acceptance/AC5_no_main_or_test_change.sh
  # M5: class files to Java 17 (parent pom release 8 -> 17), common rebuilt on JDK 17.
  fresh; sed -i 's#<release>8</release>#<release>17</release>#' pom.xml
  mvn -B -q -pl common -DskipTests clean install > /tmp/m5b.log 2>&1 || { echo "M5 build failed"; tail -20 /tmp/m5b.log; }
  bash scripts/java17s1/acceptance/AC4_jdk8_job_unchanged_class_files_java8.sh > /tmp/m5.log 2>&1; rc=$?
  grep -E 'PASS|FAIL' /tmp/m5.log | tail -1; verdict M5-classfiles-java17 AC4 $rc
  # M6: the jdk8 job edited (timeout 60 -> 61), committed.
  fresh; sed -i '0,/timeout-minutes: 60/s//timeout-minutes: 61/' .github/workflows/ci.yml
  git -c user.email=v@v -c user.name=v commit -qam m6
  bash scripts/java17s1/acceptance/AC4_jdk8_job_unchanged_class_files_java8.sh > /tmp/m6.log 2>&1; rc=$?
  tail -1 /tmp/m6.log; verdict M6-jdk8-job-edited AC4 $rc
  # M7: a comment added to one main source file, committed.
  fresh; f=$(git ls-files '*/src/main/*' | head -1); echo "// mutant" >> "$f"
  git -c user.email=v@v -c user.name=v commit -qam m7
  bash scripts/java17s1/acceptance/AC5_no_main_or_test_change.sh > /tmp/m7.log 2>&1; rc=$?
  tail -1 /tmp/m7.log; verdict "M7-main-source-edited($f)" AC5 $rc
  ;;
hbase)
  T=900
  # Baseline: AC1 needs this job's own test run; AC2 runs the server itself.
  fresh; timeout $T mvn -B -fae test -Dsurefire.timeout=400 > /tmp/b1.log 2>&1
  baseline scripts/java17s1/acceptance/AC1_jdk17_whole_build_and_tests_pass.sh
  JAVA17_RUN_WAIT_SECONDS=150 baseline scripts/java17s1/acceptance/AC2_server_and_job_on_jdk17_match_reference.sh
  # M1: Spark's module options left out of the spark-job test fork.
  fresh; sed -i '/<environmentVariables>/,/<\/environmentVariables>/d' spark-job/pom.xml
  timeout $T mvn -B -fae test -Dsurefire.timeout=400 > /tmp/m1b.log 2>&1
  bash scripts/java17s1/acceptance/AC1_jdk17_whole_build_and_tests_pass.sh > /tmp/m1.log 2>&1; rc=$?
  tail -1 /tmp/m1.log; verdict M1-no-module-options-in-test-fork AC1 $rc
  # M2: slf4j-log4j12 kept on the Java 17 test classpath (profile switched off).
  fresh; timeout $T mvn -B -fae test -P '!java9plus-tests' -Dsurefire.timeout=400 > /tmp/m2b.log 2>&1
  bash scripts/java17s1/acceptance/AC1_jdk17_whole_build_and_tests_pass.sh > /tmp/m2.log 2>&1; rc=$?
  tail -1 /tmp/m2.log; verdict M2-slf4j-log4j12-kept-in-tests AC1 $rc
  # M3a: the local job started without Spark's module options.
  fresh; printf 'SPARK_JAVA17_OPTIONS=""\nexport SPARK_JAVA17_OPTIONS\n' > scripts/java17/spark-java-options.sh
  JAVA17_RUN_WAIT_SECONDS=150 bash scripts/java17s1/acceptance/AC2_server_and_job_on_jdk17_match_reference.sh > /tmp/m3a.log 2>&1; rc=$?
  tail -1 /tmp/m3a.log; verdict M3a-job-without-module-options AC2 $rc
  # M3b: slf4j-log4j12 kept on the local job's classpath.
  fresh; sed -i "s#grep -v '/slf4j-log4j12-'#cat#" scripts/java17/spark-submit-local.sh
  JAVA17_RUN_WAIT_SECONDS=150 bash scripts/java17s1/acceptance/AC2_server_and_job_on_jdk17_match_reference.sh > /tmp/m3b.log 2>&1; rc=$?
  tail -1 /tmp/m3b.log; verdict M3b-slf4j-log4j12-kept-in-job AC2 $rc
  # M3c: the job on Java 8 (server still on 17).
  fresh; JOB_JAVA_HOME=/opt/jdk8 JAVA17_RUN_WAIT_SECONDS=150 bash scripts/java17s1/acceptance/AC2_server_and_job_on_jdk17_match_reference.sh > /tmp/m3c.log 2>&1; rc=$?
  tail -1 /tmp/m3c.log; verdict M3c-job-on-java8 AC2 $rc
  ;;
esac
