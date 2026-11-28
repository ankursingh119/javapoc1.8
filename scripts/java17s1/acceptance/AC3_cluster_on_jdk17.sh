#!/usr/bin/env bash
# AC3 The job runs on the local Docker Spark cluster on Java 17; sales_agg holds exactly the reference rows.
# Builds the salesbatch-runtime image from docker/ on a Java 17 base (--build-arg JAVA_IMAGE=eclipse-temurin:17-jre-jammy),
# checks that the image's java is 17, then runs SBJ17-11's scripts/spark35/cluster/run_job_on_docker_cluster.sh
# (unchanged): spark-submit in client mode inside spark-master, executors on the two workers, and sales_agg holding
# exactly the rows of docs/reference/report-<date>.csv.
# Runs in the JDK 17 job after AC2, so HBase's sales_raw holds the sample files. Needs the fat jar (mvn -B install).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17s1/acceptance/lib.sh

image=salesbatch-runtime
docker build -q -t "$image" --build-arg JAVA_IMAGE=eclipse-temurin:17-jre-jammy docker > /dev/null \
  || fail "the image $image does not build from docker/ on eclipse-temurin:17-jre-jammy"
v=$(docker run --rm "$image" java -version 2>&1 | tr -d '\r')
echo "$v" | grep -q 'version "17' || fail "the image $image runs $(echo "$v" | grep -m1 'version'), not java 17"

bash scripts/spark35/cluster/run_job_on_docker_cluster.sh \
  || fail "the Spark job on the Java 17 Docker cluster did not leave exactly the reference rows in sales_agg"
pass "AC3 the Spark job ran on the Docker Spark cluster on java 17 and sales_agg holds exactly the reference rows"
