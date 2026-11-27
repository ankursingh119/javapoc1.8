#!/usr/bin/env bash
# AC3 mutant c: one Java 11 class file among spark-job's classes (Scala 2.12 always emits major 52, so a scalac
# -target change is an equivalent mutant for the class half; this plants the fault directly).
V="D:/Genpact Sample/javapoc_programme/.prime/tmp/SBJ17-11/verify"
mkdir -p "$V/m3x"
printf 'public class Planted {}\n' > "$V/m3x/Planted.java"
"C:/Program Files/Eclipse Adoptium/jdk-17.0.20.101-hotspot/bin/javac" --release 11 -d "$V/m3/spark-job/target/classes" "$V/m3x/Planted.java"
echo "== mutant c: a Java 11 class file in spark-job/target/classes"
bash "$V/m3/scripts/spark35/acceptance/AC3_spark_job_java8.sh" 2>&1 | grep -E "major|PASS|FAIL"
rm -f "$V/m3/spark-job/target/classes/Planted.class"
