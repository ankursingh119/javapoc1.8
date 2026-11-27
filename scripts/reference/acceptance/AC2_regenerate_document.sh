#!/usr/bin/env bash
# AC2 docs/reference/README.md says how to regenerate them: the commands, the Docker and HBase setup, and the
# environment (SPARK_LOCAL_IP=127.0.0.1).
# Checks the document names each piece a person needs: the HBase container, the wait, the build, the capture
# script, the environment variable and the hosts entry.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/reference/acceptance/lib.sh

doc="$REF/README.md"
[ -f "$doc" ] || fail "$doc is missing"
for want in \
  "docker compose -f docker/local/docker-compose.yml up -d hbase" \
  "scripts/ci/wait-for-hbase.sh" \
  "mvn -B install" \
  "scripts/reference/capture.sh" \
  "SPARK_LOCAL_IP=127.0.0.1" \
  "host.docker.internal"; do
  grep -qF -- "$want" "$doc" || fail "$doc does not mention: $want"
done
pass "AC2 $doc gives the commands, the Docker and HBase setup and the environment"
