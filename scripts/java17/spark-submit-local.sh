#!/usr/bin/env bash
# Card SBJ17-16. A stand-in for spark-submit that runs the Spark job on a Java 17 (or any 9+) JVM, beside SBJ17-9's
# spark-submit-jdk8.sh (unchanged). The server's ProcessSparkJobLauncher calls it as
#   spark-submit-local.sh --class <main class> --master local[*] [--files <hbase-site>] <jar> <businessDate>
# and it runs <main class> on JOB_JAVA_HOME's java (default: the java on PATH) with local[*], the spark-job classpath
# and Spark's module options (scripts/java17/spark-java-options.sh), the same command LocalJvmSparkJobLauncher builds.
# Run from the repository root (the server's working directory).
# Needs: spark-job/target/classes and spark-job/target/local-classpath.txt.
# When SPARK_STANDIN_LOG is set, it appends the java version it used and its arguments there.
set -euo pipefail
. "$(dirname "$0")/spark-java-options.sh"

main=com.example.salesbatch.spark.SalesAggregator
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = --class ] && main=${args[$((i + 1))]}
done
[ ${#args[@]} -gt 0 ] || { echo "spark-submit-local: no business date" >&2; exit 2; }
date=${args[$((${#args[@]} - 1))]}

if [ -n "${JOB_JAVA_HOME:-}" ]; then java="$JOB_JAVA_HOME/bin/java"; else java=java; fi
cpfile=${SPARK_LOCAL_CLASSPATH_FILE:-spark-job/target/local-classpath.txt}
classes=${SPARK_LOCAL_CLASSES_DIR:-spark-job/target/classes}
conf=${SPARK_LOCAL_CONF_DIR:-workflow-app/src/test/resources}
[ -f "$cpfile" ] || { echo "spark-submit-local: missing $cpfile" >&2; exit 2; }

if [ -n "${SPARK_STANDIN_LOG:-}" ]; then
  { echo "args: $*"; "$java" -version 2>&1; } >> "$SPARK_STANDIN_LOG"
fi

# slf4j-log4j12 (from hadoop-client) breaks ZooKeeper's client thread on Java 9+ against Spark 3.5's log4j-1.2-api
# (MDCFriend.fixForJava9: NoSuchFieldError mdc), as in spark-job/pom.xml's java9plus-tests profile: leave it out.
cp=$(tr ':' '\n' < "$cpfile" | grep -v '/slf4j-log4j12-' | paste -sd: -)

# shellcheck disable=SC2086
exec "$java" $SPARK_JAVA17_OPTIONS -Dspark.master='local[*]' -Dspark.ui.enabled=false \
  -Dspark.driver.host=127.0.0.1 -Dspark.driver.bindAddress=127.0.0.1 \
  -cp "$conf:$classes:$cp" "$main" "$date"
