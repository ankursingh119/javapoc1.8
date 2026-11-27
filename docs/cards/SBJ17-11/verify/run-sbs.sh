#!/usr/bin/env bash
# Verify side-by-side for SBJ17-11: main (old) against the PR head (new), one side after the other, JDK 8.
set -u
V="D:/Genpact Sample/javapoc_programme/.prime/tmp/SBJ17-11/verify"
H="$V/new/docs/cards/SBJ17-11"
export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-8.0.504.1-hotspot"
export PATH="$JAVA_HOME/bin:$PATH"
export SPARK_LOCAL_IP=127.0.0.1
mkdir -p "$V/inputs" "$V/out" "$V/logs"
python -I "$H/make_inputs.py" "$V/inputs" "$V/old/sample-data"
ls "$V/inputs" | wc -l > "$V/out/input-count.txt"
for side in old new; do
  cp "$H/SbsHarnessTest.scala" "$V/$side/spark-job/src/test/scala/com/example/salesbatch/spark/"
  ( cd "$V/$side" && mvn -B -q -pl common -am install -DskipTests > "$V/logs/$side-install.log" 2>&1 )
  for env in default latin1 ar_SA; do
    case $env in
      default) jto="" ;;
      latin1) jto="-Dfile.encoding=ISO-8859-1" ;;
      ar_SA) jto="-Duser.language=ar -Duser.country=SA -Duser.timezone=Asia/Kolkata" ;;
    esac
    mkdir -p "$V/out/$side/$env"
    ( cd "$V/$side" && JAVA_TOOL_OPTIONS="$jto" SBS_INPUTS="$V/inputs" SBS_OUT="$V/out/$side/$env" \
        mvn -B -pl common,spark-job -Dtest=SbsHarnessTest -DfailIfNoTests=false -Dsurefire.failIfNoSpecifiedTests=false test \
        > "$V/logs/$side-$env.log" 2>&1 ; echo "$side $env exit $?" >> "$V/logs/exits.txt" )
  done
done
echo done
