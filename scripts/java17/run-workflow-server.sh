#!/usr/bin/env bash
# Card SBJ17-9. Run the production WorkflowServer (the shaded workflow-app.jar) on the java on PATH, against HBase in
# Docker, with the Spark job run on JDK 8 through scripts/java17/spark-submit-jdk8.sh, and drive the three sample
# files through the REST flow the way scripts/reference/capture.sh does. Writes into OUT (default
# target/java17-run), in capture.sh's format so scripts/reference/acceptance/AC4_compare_with_reference.sh applies:
#   reports/report-<date>.csv, outcome-<file>.txt, server.log, java-version.txt (the server's java),
#   spark-standin.log (each Spark job's arguments and java version)
# Needs: HBase up (docker compose -f docker/local/docker-compose.yml up -d hbase; scripts/ci/wait-for-hbase.sh 300),
# workflow-app/target/workflow-app.jar, spark-job's classes and target/local-classpath.txt built with JDK 8, and
# JAVA8_HOME. Linux or macOS (the stand-in is a shell script the server starts directly).
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
OUT=${1:-target/java17-run}
PORT=${JAVA17_RUN_PORT:-18082}
WAIT=${JAVA17_RUN_WAIT_SECONDS:-300}
BASE="http://localhost:$PORT"
JAR=workflow-app/target/workflow-app.jar

rm -rf "$OUT"; mkdir -p "$OUT/reports"
OUT_ABS=$(cd "$OUT" && pwd)
[ -f "$JAR" ] || { echo "run: missing $JAR (build workflow-app)" >&2; exit 1; }
: "${JAVA8_HOME:?run: set JAVA8_HOME to a JDK 8 for the Spark job}"
chmod +x scripts/java17/spark-submit-jdk8.sh

java -version > "$OUT/java-version.txt" 2>&1
SPARK_STANDIN_LOG="$OUT_ABS/spark-standin.log" JAVA8_HOME="$JAVA8_HOME" \
java -Dserver.port="$PORT" -Dreport.dir="$OUT_ABS/reports" \
  "-Dactiviti.jdbc.url=jdbc:h2:mem:java17run;DB_CLOSE_DELAY=-1" \
  -Dspark.submit.command="$ROOT/scripts/java17/spark-submit-jdk8.sh" \
  '-Dspark.master=local[*]' -Dspark.hbase.site= \
  -cp "workflow-app/src/test/resources:$JAR" com.example.salesbatch.workflow.WorkflowServer > "$OUT/server.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT

up=no
for _ in $(seq 1 120); do
  kill -0 "$PID" 2>/dev/null || { echo "run: the server stopped; see $OUT/server.log" >&2; tail -60 "$OUT/server.log" >&2; exit 1; }
  if curl -s -o /dev/null "$BASE/"; then up=yes; break; fi
  sleep 1
done
[ "$up" = yes ] || { echo "run: the server did not answer on $PORT in 120 s" >&2; tail -60 "$OUT/server.log" >&2; exit 1; }

# Value of one string field of the flat JSON the API returns, with \" and \\ unescaped.
field() {
  printf '%s' "$1" | sed -nE "s/.*\"$2\":\"((\\\\.|[^\"\\\\])*)\".*/\\1/p" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

poll() {
  local id=$1 want=$2 body st
  for _ in $(seq 1 "$WAIT"); do
    body=$(curl -s "$BASE/batches/$id")
    st=$(field "$body" status)
    for w in $want; do [ "$st" = "$w" ] && { printf '%s' "$body"; return 0; }; done
    sleep 1
  done
  printf '%s' "$body"
}

run() { # file date
  local file=$1 date=$2 body id st err waited=no
  body=$(curl -s -X POST "$BASE/batches" -H "Content-Type: application/json" \
    -d "{\"csvPath\":\"$ROOT/sample-data/$file\",\"businessDate\":\"$date\"}")
  id=$(field "$body" processInstanceId)
  [ -n "$id" ] || { echo "run: $file was not started: $body" >&2; return 1; }
  body=$(poll "$id" "WAITING_APPROVAL FAILED COMPLETED REJECTED")
  if [ "$(field "$body" status)" = WAITING_APPROVAL ]; then
    waited=yes
    curl -s -X POST "$BASE/batches/$id/approve?approved=true&approver=java17-run" > /dev/null
    body=$(poll "$id" "FAILED COMPLETED REJECTED")
  fi
  st=$(field "$body" status); err=$(field "$body" error)
  {
    echo "file=$file"
    echo "businessDate=$date"
    echo "status=$st"
    echo "error=$err"
    if [ -f "$OUT/reports/report-$date.csv" ]; then echo "report=yes"; else echo "report=no"; fi
  } > "$OUT/outcome-$file.txt"
  echo "$waited" > "$OUT/waited-approval-$file.txt"
  echo "run: $file $date -> $st${err:+ ($err)} (waited for approval: $waited)"
}

run sales-20261113.csv 20261113
run sales-20261115.csv 20261115
run sales-bad.csv 20261116
