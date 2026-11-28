#!/usr/bin/env bash
# Verify, SBJ17-16: M4, the Dockerfile's Java base pinned back to Java 8 (the build argument ignored). AC3 must fail.
# The unmutated AC3 passed in the pipeline (runs 46125361261, 46125365710), which is its baseline.
set -uo pipefail
cd "$(dirname "$0")"
rm -rf mut4; mkdir mut4
git -C head archive HEAD docker scripts | tar -x -C mut4
sed -i 's#^FROM \${JAVA_IMAGE}#FROM eclipse-temurin:8-jre-jammy#' mut4/docker/Dockerfile
grep -n '^FROM' mut4/docker/Dockerfile
cd mut4
bash scripts/java17s1/acceptance/AC3_cluster_on_jdk17.sh > ../mutant-ac3.log 2>&1; rc=$?
tail -2 ../mutant-ac3.log
if [ $rc -ne 0 ]; then echo "MUTANT M4-dockerfile-base-java8 AC3 -> KILLED"; else echo "MUTANT M4-dockerfile-base-java8 AC3 -> SURVIVED"; fi
docker rmi salesbatch-runtime > /dev/null 2>&1 || true
