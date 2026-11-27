#!/usr/bin/env bash
# Card SBJ17-9. A stand-in for spark-submit, for running the production WorkflowServer on JDK 17 while the Scala job
# (Spark 3.5.5, Scala 2.12, since card SBJ17-11) is built and tested on JDK 8. The server's ProcessSparkJobLauncher calls it as
#   spark-submit-jdk8.sh --class <main class> --master local[*] [--files <hbase-site>] <jar> <businessDate>
# and it runs <main class> on JAVA8_HOME's java with local[*] and the spark-job classpath, the same command the
# test launcher LocalJvmSparkJobLauncher builds. Run from the repository root (the server's working directory).
# Needs: JAVA8_HOME, spark-job/target/classes and spark-job/target/local-classpath.txt built with JDK 8.
# When SPARK_STANDIN_LOG is set, it appends the java version it used and its arguments there.
set -euo pipefail

main=com.example.salesbatch.spark.SalesAggregator
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = --class ] && main=${args[$((i + 1))]}
done
[ ${#args[@]} -gt 0 ] || { echo "spark-submit-jdk8: no business date" >&2; exit 2; }
date=${args[$((${#args[@]} - 1))]}

: "${JAVA8_HOME:?spark-submit-jdk8: set JAVA8_HOME to a JDK 8}"
java8="$JAVA8_HOME/bin/java"
cpfile=${SPARK_LOCAL_CLASSPATH_FILE:-spark-job/target/local-classpath.txt}
classes=${SPARK_LOCAL_CLASSES_DIR:-spark-job/target/classes}
conf=${SPARK_LOCAL_CONF_DIR:-workflow-app/src/test/resources}
[ -f "$cpfile" ] || { echo "spark-submit-jdk8: missing $cpfile" >&2; exit 2; }

if [ -n "${SPARK_STANDIN_LOG:-}" ]; then
  { echo "args: $*"; "$java8" -version 2>&1; } >> "$SPARK_STANDIN_LOG"
fi

exec "$java8" -Dspark.master='local[*]' -Dspark.ui.enabled=false \
  -Dspark.driver.host=127.0.0.1 -Dspark.driver.bindAddress=127.0.0.1 \
  -cp "$conf:$classes:$(cat "$cpfile")" "$main" "$date"
