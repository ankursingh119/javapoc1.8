#!/usr/bin/env bash
# Verify, SBJ17-16: side-by-side, main (server and job on Java 8, main's own JDK 8 stand-in) against the PR head
# (server and job on Java 17, the head's spark-submit-local.sh), over the sweep, in three environments.
# Each (version, environment) gets a fresh HBase. Output: out/<version>-<env>/.
set -uo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1
COMPOSE=head/docker/local/docker-compose.yml
mkdir -p out
one() { # version env list opts
  local v=$1 e=$2 list=$3 opts=$4 name="sbs-$1-$2" standin
  if [ "$v" = old ]; then standin=scripts/java17/spark-submit-jdk8.sh; else standin=scripts/java17/spark-submit-local.sh; fi
  echo "== $v $e $(date -u +%T)"
  docker compose -f "$COMPOSE" down -v > /dev/null 2>&1
  docker compose -f "$COMPOSE" up -d hbase > /dev/null 2>&1
  bash head/scripts/ci/wait-for-hbase.sh 300 | tail -1
  docker rm -f "$name" > /dev/null 2>&1
  docker run --name "$name" --network host --add-host host.docker.internal:127.0.0.1 \
    -e STANDIN="$standin" -e JAVA_TOOL_OPTIONS="$opts" "sbj1716-$v" bash /drive.sh /out "/sweep/$list" \
    > "out/$v-$e.drive.log" 2>&1
  rm -rf "out/$v-$e"; docker cp "$name:/out" "out/$v-$e" > /dev/null
  docker rm "$name" > /dev/null
  echo "scan 'sales_agg'" | docker exec -i sales-hbase hbase shell -n > "out/$v-$e/hbase-sales_agg.txt" 2>&1
  tail -3 "out/$v-$e.drive.log"
}
LATIN1='-Dfile.encoding=ISO-8859-1 -Dsun.jnu.encoding=ISO-8859-1'
AR='-Duser.language=ar -Duser.country=EG -Duser.timezone=Pacific/Kiritimati'
for v in old new; do one "$v" default inputs-all.txt ''; done
for v in old new; do one "$v" latin1 inputs-env.txt "$LATIN1"; done
for v in old new; do one "$v" ar inputs-env.txt "$AR"; done
docker compose -f "$COMPOSE" down -v > /dev/null 2>&1
echo "== done $(date -u +%T)"
