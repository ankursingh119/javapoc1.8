#!/usr/bin/env bash
# Verify, SBJ17-16: runs inside the runner container, from /work (a clone). Starts the production WorkflowServer
# (workflow-app.jar) the way scripts/java17/run-workflow-server.sh does, then sends every input of LIST through the
# REST flow (POST /batches, poll, approve what waits). The Spark job runs through STANDIN.
#   drive.sh OUT LIST          env: STANDIN (script path in /work), JAVA8_HOME, JAVA_TOOL_OPTIONS (environment axis)
set -uo pipefail
cd /work
OUT=$1; LIST=$2; PORT=18090; WAIT=240; BASE="http://localhost:$PORT"
rm -rf "$OUT"; mkdir -p "$OUT/reports"
chmod +x "$STANDIN"
java -version > "$OUT/java-version.txt" 2>&1
SPARK_STANDIN_LOG="$OUT/spark-standin.log" \
java -Dserver.port="$PORT" -Dreport.dir="$OUT/reports" \
  "-Dactiviti.jdbc.url=jdbc:h2:mem:sbs;DB_CLOSE_DELAY=-1" \
  -Dspark.submit.command="/work/$STANDIN" \
  '-Dspark.master=local[*]' -Dspark.hbase.site= \
  -cp "workflow-app/src/test/resources:workflow-app/target/workflow-app.jar" \
  com.example.salesbatch.workflow.WorkflowServer > "$OUT/server.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for _ in $(seq 1 120); do curl -s -o /dev/null "$BASE/" && break; sleep 1; done
curl -s -o /dev/null "$BASE/" || { echo "drive: server did not start"; tail -40 "$OUT/server.log"; exit 1; }

field() { printf '%s' "$1" | sed -nE "s/.*\"$2\":\"((\\\\.|[^\"\\\\])*)\".*/\\1/p" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'; }
poll() {
  local id=$1 want=$2 body st
  for _ in $(seq 1 "$WAIT"); do
    body=$(curl -s "$BASE/batches/$id"); st=$(field "$body" status)
    for w in $want; do [ "$st" = "$w" ] && { printf '%s' "$body"; return 0; }; done
    sleep 1
  done
  printf '%s' "$body"
}
while read -r file date; do
  [ -n "$file" ] || continue
  body=$(curl -s -X POST "$BASE/batches" -H "Content-Type: application/json" \
    -d "{\"csvPath\":\"/sweep/$file\",\"businessDate\":\"$date\"}")
  id=$(field "$body" processInstanceId)
  waited=no
  if [ -z "$id" ]; then st=NOT_STARTED; err=$body; else
    body=$(poll "$id" "WAITING_APPROVAL FAILED COMPLETED REJECTED")
    if [ "$(field "$body" status)" = WAITING_APPROVAL ]; then
      waited=yes
      curl -s -X POST "$BASE/batches/$id/approve?approved=true&approver=verify" > /dev/null
      body=$(poll "$id" "FAILED COMPLETED REJECTED")
    fi
    st=$(field "$body" status); err=$(field "$body" error)
  fi
  {
    echo "file=$file"; echo "businessDate=$date"; echo "status=$st"; echo "error=$err"; echo "waitedApproval=$waited"
    if [ -f "$OUT/reports/report-$date.csv" ]; then echo "report=yes"; else echo "report=no"; fi
  } > "$OUT/outcome-$file.txt"
  echo "drive: $file $date -> $st${err:+ ($err)}"
done < "$LIST"
