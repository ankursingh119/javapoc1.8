#!/usr/bin/env bash
# Card SBJ17-11 (docs/cards/SBJ17-11.md, Build): run the Spark job on the local Docker Spark cluster
# (docker/local/docker-compose.yml: spark-master and two workers on the salesbatch-runtime image, Spark 3.5 on
# Hadoop 3) the way DockerClusterSparkJobLauncher does, and check what it writes to HBase.
# Runs in the JDK 8 job after the reference compare, so HBase's sales_raw holds the three sample files. Steps:
# - starts the three Spark containers (the image is built from docker/ if missing);
# - empties sales_agg, then for each reference date runs spark-submit inside spark-master in client mode, so the
#   driver runs there and the executors on the workers; each run must exit 0 and be granted executors;
# - scans sales_agg and checks it holds exactly the rows of docs/reference/report-<date>.csv: every row key with
#   totalQty, totalAmount and orderCount equal to the report's, and no other row key.
# Output in target/spark35-cluster/. Needs HBase up and the fat jar built (mvn -B install).
set -euo pipefail
cd "$(dirname "$0")/../../.."

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

OUT=target/spark35-cluster
JAR=spark-job/target/spark-job-1.0.0-SNAPSHOT.jar
HBASE_CONTAINER=${HBASE_CONTAINER:-sales-hbase}
rm -rf "$OUT"; mkdir -p "$OUT"

[ -f "$JAR" ] || fail "$JAR is missing (mvn -B install builds it)"
docker image inspect salesbatch-runtime > /dev/null 2>&1 || docker build -q -t salesbatch-runtime docker > /dev/null \
  || fail "the image salesbatch-runtime does not build from docker/"

compose=(docker compose -f docker/local/docker-compose.yml)
[ "$(uname -s)" = Linux ] && compose+=(-f scripts/spark35/cluster/linux-host.yml)
"${compose[@]}" up -d spark-master spark-worker-1 spark-worker-2 > "$OUT/compose-up.txt" 2>&1 \
  || { cat "$OUT/compose-up.txt" >&2; fail "the Spark cluster containers did not start"; }

workers=0
for _ in $(seq 1 90); do
  workers=$(curl -s http://localhost:8090/json/ | tr -d ' \n' | sed -nE 's/.*"aliveworkers":([0-9]+).*/\1/p')
  [ "${workers:-0}" -ge 2 ] && break
  sleep 2
done
[ "${workers:-0}" -ge 2 ] || { docker logs --tail 80 spark-master >&2; fail "spark-master has ${workers:-0} live workers, not 2"; }
echo "cluster: spark-master up with $workers workers"

echo "truncate 'sales_agg'" | docker exec -i "$HBASE_CONTAINER" hbase shell -n > "$OUT/truncate.txt" 2>&1 \
  || { cat "$OUT/truncate.txt" >&2; fail "sales_agg could not be emptied"; }

for report in docs/reference/report-*.csv; do
  date=$(basename "$report" .csv); date=${date#report-}
  log="$OUT/spark-submit-$date.log"
  if ! docker exec -i spark-master /opt/spark/bin/spark-submit \
      --class com.example.salesbatch.spark.SalesAggregator \
      --master spark://spark-master:7077 --deploy-mode client \
      --conf spark.driver.host=spark-master --conf spark.ui.enabled=false --conf spark.executor.memory=512m \
      "/work/$JAR" "$date" > "$log" 2>&1; then
    tail -60 "$log" >&2
    fail "spark-submit for $date on the cluster exited non-zero (log $log)"
  fi
  grep -q "Granted executor ID" "$log" || { tail -60 "$log" >&2; fail "the $date run was granted no executor on the workers"; }
  echo "cluster: $date ran, $(grep -c 'Granted executor ID' "$log") executors granted"
done

scan="$OUT/hbase-sales_agg.txt"
echo "scan 'sales_agg'" | docker exec -i "$HBASE_CONTAINER" hbase shell -n > "$scan" 2>&1 || true
tr -d '\r' < "$scan" > "$scan.clean"

n=0; : > "$OUT/expected-keys.txt"
for report in docs/reference/report-*.csv; do
  while IFS=, read -r date region product qty amount count; do
    [ "$date" = date ] && continue
    [ -n "$date" ] || continue
    key="${date}_${region}_${product}"
    echo "$key" >> "$OUT/expected-keys.txt"
    for pair in "totalQty=$qty" "totalAmount=$amount" "orderCount=$count"; do
      col=${pair%%=*}; val=${pair#*=}; val=${val//./\\.}
      grep -qE "^ *${key} +column=a:${col}, .*value=${val}\$" "$scan.clean" \
        || fail "sales_agg after the cluster run has no $key a:$col = $val (from $report)"
    done
    n=$((n + 1))
  done < <(tr -d '\r' < "$report")
done
[ "$n" -gt 0 ] || fail "the reference reports have no data rows"

sed -nE 's/^ *([0-9]{8}_[^ ]+) +column=.*/\1/p' "$scan.clean" | sort -u > "$OUT/found-keys.txt"
extra=$(comm -13 <(sort -u "$OUT/expected-keys.txt") "$OUT/found-keys.txt")
[ -z "$extra" ] || fail "sales_agg after the cluster run has rows the reports do not: $extra"

pass "the Spark job ran on the Docker cluster (Spark 3.5, two workers) and sales_agg holds exactly the $n reference report rows"
