# Card SBJ17-16 made the Java base an argument; card SBJ17-17 made Java 17 its default (the job's class files are
# Java 17). Spark 3.5's spark-submit adds its own module options on Java 17.
ARG JAVA_IMAGE=eclipse-temurin:17-jre-jammy
FROM ${JAVA_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends curl procps && rm -rf /var/lib/apt/lists/*
# Spark 3.5.5 built for Hadoop 3 and Scala 2.12 (card SBJ17-11), on Java 17 like the job's class files.
RUN curl -fsSL https://archive.apache.org/dist/spark/spark-3.5.5/spark-3.5.5-bin-hadoop3.tgz | tar -xz -C /opt \
 && mv /opt/spark-3.5.5-bin-hadoop3 /opt/spark
ENV SPARK_HOME=/opt/spark PATH=/opt/spark/bin:$PATH
# hbase-site.xml in Spark's conf dir (on the driver classpath) and in /conf (for the workflow app)
COPY hbase-site.xml /opt/spark/conf/hbase-site.xml
COPY hbase-site.xml /conf/hbase-site.xml
WORKDIR /work
