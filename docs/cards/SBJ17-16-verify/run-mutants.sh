#!/usr/bin/env bash
# Verify, SBJ17-16: runs mutants.sh <static|hbase> in a fresh sbj1716-new container; log to mutants-<mode>.log.
set -uo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1
mode=$1
name="sbs-mut-$mode"
docker rm -f "$name" > /dev/null 2>&1
if [ "$mode" = hbase ]; then
  docker compose -f head/docker/local/docker-compose.yml down -v > /dev/null 2>&1
  docker compose -f head/docker/local/docker-compose.yml up -d hbase > /dev/null 2>&1
  bash head/scripts/ci/wait-for-hbase.sh 300 | tail -1
  net=(--network host --add-host host.docker.internal:127.0.0.1)
else
  net=()
fi
docker create --name "$name" "${net[@]}" sbj1716-new bash /mutants.sh "$mode" > /dev/null
docker cp mutants.sh "$name:/mutants.sh"
docker start -a "$name" > "mutants-$mode.log" 2>&1
docker rm "$name" > /dev/null
[ "$mode" = hbase ] && docker compose -f head/docker/local/docker-compose.yml down -v > /dev/null 2>&1
grep -E 'BASELINE|MUTANT|failed' "mutants-$mode.log"
