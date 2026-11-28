# syntax=docker/dockerfile:1
# Verify, SBJ17-16: side-by-side runner. Both images hold JDK 17 (default) and JDK 8 (/opt/jdk8), Maven and curl.
# old = main 33e45df built as main's pipeline builds it (JDK 8); new = PR head d66492e built as its JDK 17 job does.
# The Maven repository is /m2 inside the image (MAVEN_ARGS), because local-classpath.txt points into it.
FROM maven:3.9.9-eclipse-temurin-17 AS base
COPY --from=eclipse-temurin:8u442-b06-jdk-jammy /opt/java/openjdk /opt/jdk8
ENV JAVA8_HOME=/opt/jdk8 SPARK_LOCAL_IP=127.0.0.1 MAVEN_ARGS=-Dmaven.repo.local=/m2
RUN (command -v curl || (apt-get update && apt-get install -y --no-install-recommends curl)) > /dev/null

FROM base AS old
COPY main /work
WORKDIR /work
RUN JAVA_HOME=/opt/jdk8 mvn -B -q install -DskipTests \
 && JAVA_HOME=/opt/jdk8 mvn -B -q -pl spark-job -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/local-classpath.txt
ENV PATH=/opt/jdk8/bin:$PATH JAVA_HOME=/opt/jdk8
COPY sweep /sweep
COPY drive.sh /drive.sh

FROM base AS new
COPY head /work
WORKDIR /work
RUN mvn -B -q install -DskipTests \
 && JAVA_HOME=/opt/jdk8 mvn -B -q -pl spark-job -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/local-classpath.txt
COPY sweep /sweep
COPY drive.sh /drive.sh
