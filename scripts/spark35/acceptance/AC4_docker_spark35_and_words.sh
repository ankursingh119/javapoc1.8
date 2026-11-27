#!/usr/bin/env bash
# AC4 The local Docker Spark cluster image runs Spark 3.5 with Scala 2.12, and the README and the comments in
# `docker/` and `scripts/` name Spark 3.5 and Scala 2.12, not Spark 2.4 or Scala 2.11.
# Builds the image the local cluster uses (docker/local/docker-compose.yml: salesbatch-runtime, from docker/) and
# reads `spark-submit --version` inside it: version 3.5.x and Scala version 2.12.x. Then README.md and every file
# under docker/ and scripts/ (this card's own checks under scripts/spark35/ excepted, since they name the old
# versions to look for them) must not name Spark 2.4, Scala 2.11 or their builds, and README.md must name Spark 3.5
# and Scala 2.12. Set SKIP_IMAGE=1 to run only the words part (no Docker).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/spark35/acceptance/lib.sh

if [ "${SKIP_IMAGE:-0}" != 1 ]; then
  docker build -q -t salesbatch-runtime docker > /dev/null || fail "the image salesbatch-runtime does not build from docker/"
  out=$(docker run --rm salesbatch-runtime spark-submit --version 2>&1 | tr -d '\r')
  echo "$out" | grep -qE 'version 3\.5\.[0-9]+' || { echo "$out" >&2; fail "the image's spark-submit is not Spark 3.5"; }
  echo "$out" | grep -qE 'Scala version 2\.12\.[0-9]+' || { echo "$out" >&2; fail "the image's Spark is not built for Scala 2.12"; }
  echo "image: $(echo "$out" | grep -oE 'version 3\.5\.[0-9]+' | head -1), $(echo "$out" | grep -oE 'Scala version 2\.12\.[0-9]+' | head -1)"
fi

old='Spark 2\.4|spark-2\.4|2\.4\.8|Scala 2\.11|2\.11\.12|_2\.11|hadoop2\.7'
hits=$(grep -rnE "$old" README.md docker scripts --exclude-dir=spark35 || true)
if [ -n "$hits" ]; then
  echo "$hits" >&2
  fail "README.md, docker/ or scripts/ still name Spark 2.4 or Scala 2.11"
fi
grep -qE 'Spark 3\.5' README.md || fail "README.md does not name Spark 3.5"
grep -qE 'Scala 2\.12' README.md || fail "README.md does not name Scala 2.12"
pass "AC4 the local cluster image runs Spark 3.5 on Scala 2.12, and README, docker/ and scripts/ name only those"
