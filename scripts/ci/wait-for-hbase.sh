#!/usr/bin/env bash
# Wait until the HBase container started by docker/local/docker-compose.yml serves: one active master and at least
# one live region server, asked from inside the container. On Linux docker-proxy accepts on the published ports as
# soon as the container starts, so a port probe from the host says nothing about readiness.
# Usage: scripts/ci/wait-for-hbase.sh [timeout seconds, default 300]
set -uo pipefail
container=sales-hbase
timeout=${1:-300}
deadline=$((SECONDS + timeout))
while [ "$SECONDS" -lt "$deadline" ]; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" != "true" ]; then
    echo "HBase container $container is not running" >&2
    docker logs --tail 200 "$container" >&2 2>&1 || true
    exit 1
  fi
  status=$(echo "status" | docker exec -i "$container" /hbase/bin/hbase shell -n 2>/dev/null | grep -E 'active master' || true)
  if echo "$status" | grep -qE '^1 active master, .* [1-9][0-9]* servers'; then
    echo "HBase is serving after ${SECONDS}s: $status"
    exit 0
  fi
  echo "waiting for HBase (${SECONDS}s): ${status:-no answer yet}"
  sleep 5
done
echo "HBase did not serve within ${timeout}s" >&2
docker logs --tail 200 "$container" >&2 2>&1 || true
exit 1
