# Card SBJ17-16: the Java base is an argument. The default stays Java 8 (the JDK 8 job and the README's local stack);
# the JDK 17 job builds with --build-arg JAVA_IMAGE=eclipse-temurin:17-jre-jammy, and Spark 3.5's spark-submit adds
# its own module options there.
ARG JAVA_IMAGE=eclipse-temurin:8-jre-jammy
FROM ${JAVA_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends curl procps && rm -rf /var/lib/apt/lists/*
# Spark 3.5.5 built for Hadoop 3 and Scala 2.12 (card SBJ17-11), on Java 8 like the job's class files.
RUN curl -fsSL https://archive.apache.org/dist/spark/spark-3.5.5/spark-3.5.5-bin-hadoop3.tgz | tar -xz -C /opt \
 && mv /opt/spark-3.5.5-bin-hadoop3 /opt/spark
ENV SPARK_HOME=/opt/spark PATH=/opt/spark/bin:$PATH
# hbase-site.xml in Spark's conf dir (on the driver classpath) and in /conf (for the workflow app)
COPY hbase-site.xml /opt/spark/conf/hbase-site.xml
COPY hbase-site.xml /conf/hbase-site.xml
WORKDIR /work
