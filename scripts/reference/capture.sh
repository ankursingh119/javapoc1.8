#!/usr/bin/env bash
# Card SBJ17-8. Run today's application on the three sample files and keep what it produces.
#   bash scripts/reference/capture.sh [OUT]      (OUT defaults to target/reference-run)
# Needs: HBase up (docker compose -f docker/local/docker-compose.yml up -d hbase; scripts/ci/wait-for-hbase.sh 300),
# a JDK 17 on PATH (card SBJ17-17), and `mvn -B install` done once. Run from anywhere; it works from the repository root.
# It builds the classpath files (README 3.2) unless SKIP_BUILD=1, starts LocalDebugServer (real HBase, the Scala job
# in a child JVM with local[*]), runs each file through the REST flow, approves what waits, and writes into OUT:
#   reports/report-<date>.csv          the reports the application wrote
#   outcome-<file>.txt                 file, businessDate, final status, error text, report written yes or no
#   server.log                         the server's own log
# Use each business date once on a fresh HBase: a second run of the same date has not been verified (README 5).
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT=$(pwd -W 2>/dev/null || pwd)
OUT=${1:-target/reference-run}
PORT=${REFERENCE_PORT:-18081}
WAIT=${REFERENCE_WAIT_SECONDS:-300}
BASE="http://localhost:$PORT"

rm -rf "$OUT"; mkdir -p "$OUT/reports"
OUT_ABS=$(cd "$OUT" && (pwd -W 2>/dev/null || pwd))

if [ "${SKIP_BUILD:-0}" != 1 ]; then
  mvn -B -q -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/local-classpath.txt
fi
for f in workflow-app/target/local-classpath.txt spark-job/target/local-classpath.txt workflow-app/target/test-classes; do
  [ -e "$f" ] || { echo "capture: missing $f (run the build, README 3.2)" >&2; exit 1; }
done

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SEP=';' ;; *) SEP=':' ;; esac
CP="workflow-app/target/test-classes${SEP}workflow-app/target/classes${SEP}$(cat workflow-app/target/local-classpath.txt)"

# Card SBJ17-17: the project runs on Java 17. The Scala job's child JVM (LocalJvmSparkJobLauncher, a test source
# that stays unchanged) inherits JDK_JAVA_OPTIONS, so Spark's module options reach it that way, and it reads its
# classpath from a copy without slf4j-log4j12 (on Java 9+ that binding breaks ZooKeeper's client thread against
# Spark 3.5's log4j-1.2-api; spark-job/pom.xml and scripts/java17/spark-submit-local.sh leave it out the same way).
. scripts/java17/spark-java-options.sh
export JDK_JAVA_OPTIONS="$SPARK_JAVA17_OPTIONS"
JOB_CP="$OUT/spark-job-classpath.txt"
tr "$SEP" '\n' < spark-job/target/local-classpath.txt | grep -v 'slf4j-log4j12-' | paste -sd"$SEP" - > "$JOB_CP"

java -Dserver.port="$PORT" -Dreport.dir="$OUT_ABS/reports" \
  "-Dactiviti.jdbc.url=jdbc:h2:mem:reference;DB_CLOSE_DELAY=-1" \
  -Dspark.local.classpath.file="$OUT_ABS/spark-job-classpath.txt" \
  -cp "$CP" com.example.salesbatch.workflow.LocalDebugServer > "$OUT/server.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT

up=no
for _ in $(seq 1 120); do
  kill -0 "$PID" 2>/dev/null || { echo "capture: the server stopped; see $OUT/server.log" >&2; tail -40 "$OUT/server.log" >&2; exit 1; }
  if curl -s -o /dev/null "$BASE/"; then up=yes; break; fi
  sleep 1
done
[ "$up" = yes ] || { echo "capture: the server did not answer on $PORT in 120 s" >&2; exit 1; }

# Value of one string field of the flat JSON the API returns, with \" and \\ unescaped.
field() {
  printf '%s' "$1" | sed -nE "s/.*\"$2\":\"((\\\\.|[^\"\\\\])*)\".*/\\1/p" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

# Poll until the status is one of the given (space separated) values or the time limit passes; print the last body.
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
  local file=$1 date=$2 body id st err
  body=$(curl -s -X POST "$BASE/batches" -H "Content-Type: application/json" \
    -d "{\"csvPath\":\"$ROOT/sample-data/$file\",\"businessDate\":\"$date\"}")
  id=$(field "$body" processInstanceId)
  [ -n "$id" ] || { echo "capture: $file was not started: $body" >&2; return 1; }
  body=$(poll "$id" "WAITING_APPROVAL FAILED COMPLETED REJECTED")
  if [ "$(field "$body" status)" = WAITING_APPROVAL ]; then
    curl -s -X POST "$BASE/batches/$id/approve?approved=true&approver=reference-capture" > /dev/null
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
  echo "capture: $file $date -> $st${err:+ ($err)}"
}

run sales-20261113.csv 20261113
run sales-20261115.csv 20261115
run sales-bad.csv 20261116

# Provenance: which Java ran, and what the real HBase holds in sales_agg (only the Spark job writes that table, so its
# rows show the real job ran against the real HBase). Skipped when the HBase container is not reachable.
java -version > "$OUT/java-version.txt" 2>&1 || true
HBASE_CONTAINER=${HBASE_CONTAINER:-sales-hbase}
if docker inspect "$HBASE_CONTAINER" > /dev/null 2>&1; then
  echo "scan 'sales_agg'" | docker exec -i "$HBASE_CONTAINER" hbase shell -n > "$OUT/hbase-sales_agg.txt" 2>&1 || true
  echo "capture: sales_agg scanned from container $HBASE_CONTAINER into $OUT/hbase-sales_agg.txt"
else
  echo "capture: no container $HBASE_CONTAINER, sales_agg not scanned"
fi
