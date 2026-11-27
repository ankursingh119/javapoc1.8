FROM eclipse-temurin:8-jre-jammy
RUN apt-get update && apt-get install -y --no-install-recommends curl procps && rm -rf /var/lib/apt/lists/*
# Spark 3.5.5 built for Hadoop 3 and Scala 2.12 (card SBJ17-11), on Java 8 like the job's class files.
RUN curl -fsSL https://archive.apache.org/dist/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz | tar -xz -C /opt \
 && mv /opt/spark-2.4.8-bin-hadoop2.7 /opt/spark
ENV SPARK_HOME=/opt/spark PATH=/opt/spark/bin:$PATH
# hbase-site.xml in Spark's conf dir (on the driver classpath) and in /conf (for the workflow app)
COPY hbase-site.xml /opt/spark/conf/hbase-site.xml
COPY hbase-site.xml /conf/hbase-site.xml
WORKDIR /work
