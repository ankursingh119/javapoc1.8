#!/usr/bin/env bash
# Card SBJ17-16. Spark 3.5's module options for Java 17 (Spark's own list, org.apache.spark.launcher.JavaModuleOptions),
# for a JVM that runs Spark without spark-submit. Sourced: sets SPARK_JAVA17_OPTIONS. The same list is in
# spark-job/pom.xml (surefire's JDK_JAVA_OPTIONS); keep the two equal.
SPARK_JAVA17_OPTIONS="-XX:+IgnoreUnrecognizedVMOptions \
--add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.net=ALL-UNNAMED \
--add-opens=java.base/java.nio=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
--add-opens=java.base/jdk.internal.ref=ALL-UNNAMED \
--add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens=java.base/sun.nio.cs=ALL-UNNAMED \
--add-opens=java.base/sun.security.action=ALL-UNNAMED \
--add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
-Djdk.reflect.useDirectMethodHandle=false \
-Dio.netty.tryReflectionSetAccessible=true"
export SPARK_JAVA17_OPTIONS
