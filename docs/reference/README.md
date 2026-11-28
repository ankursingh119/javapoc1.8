# Reference reports (card SBJ17-8)

What today's application writes for the three sample files, recorded before the Java 17 upgrade so every later
change can be compared with it. The pipeline's JDK 8 job reruns the three files on every push and fails when the
result differs (`scripts/reference/acceptance/AC4_compare_with_reference.sh`).

## What is here

| File | What it is |
|---|---|
| `report-20261113.csv` | The report for `sample-data/sales-20261113.csv`, business date 20261113, after approval |
| `report-20261115.csv` | The report for `sample-data/sales-20261115.csv`, business date 20261115, after approval |
| `sales-bad.outcome.txt` | What happens to `sample-data/sales-bad.csv`, business date 20261116: final status, error text, whether a report is written |

`sales-bad.csv` is rejected: status `FAILED`, error `Line 3: bad number (For input string: "notanumber")`, no
report, no approval step. The text in brackets is the Java runtime's own message, so a Java upgrade may change it;
the compare then fails on purpose and a person decides whether the new text is acceptable.

## Where they came from

- Code from main commit: `01b93f842a1248b721ca6aaa6a220dd81d008761` (the card's branch changes nothing under `src/`).
- Captured by the pipeline (GitHub Actions, workflow CI, job "JDK 8", Ubuntu, Temurin JDK 8) on the card's branch,
  run 45987601807 (commit `df9c045`), artifact `reference-run-jdk8`, copied here unchanged. The run before it,
  45987121927 (commit `9ca8462`), produced the same two reports and the same outcome byte for byte. Java
  `1.8.0_514` (Temurin). HBase's `sales_agg` held exactly the rows of both reports after the run, and none for
  20261116.
- Stack: Java 8, the Scala job on Spark 2.4.8 in a child JVM with `local[*]`, HBase 1.4 in Docker
  (`docker/local/docker-compose.yml`), workflow state in an in-memory H2 database.
- Each business date was run once on a fresh HBase container. A second run of the same date on the same HBase has
  not been verified (README section 5), so regenerate on a fresh container.

## How to regenerate

### In the pipeline

Every push runs the capture and the compare in job "JDK 8"; the run's artifact `reference-run-jdk8` holds the
reports, the outcome files, the server log, the Java version and a scan of HBase's `sales_agg` table. To take a new
reference (only when a person has agreed the change in the reports), copy from that artifact:
`reports/report-20261113.csv`, `reports/report-20261115.csv` and `outcome-sales-bad.csv.txt` (as
`sales-bad.outcome.txt`), and update the commit and run above.

### On a Linux machine, or Windows with Git Bash and Docker in WSL (README sections 3 and 4)

From the repository root, with JDK 8 and Maven on `PATH` and Docker running:

```
export SPARK_LOCAL_IP=127.0.0.1
echo "127.0.0.1 host.docker.internal" | sudo tee -a /etc/hosts   # Linux only; Docker Desktop on Windows has it
docker compose -f docker/local/docker-compose.yml down -v          # start from a fresh HBase
docker compose -f docker/local/docker-compose.yml up -d hbase
bash scripts/ci/wait-for-hbase.sh 300
mvn -B install
bash scripts/reference/capture.sh target/reference-run
REFERENCE_RUN=target/reference-run bash scripts/reference/acceptance/AC4_compare_with_reference.sh
```

`SPARK_LOCAL_IP=127.0.0.1` keeps the Spark child JVM on the loopback address, as the pipeline does.
`host.docker.internal` is the HBase host in `workflow-app/src/test/resources/hbase-site.xml`.
`capture.sh` builds the classpath files (README 3.2: `mvn -B -DskipTests package dependency:build-classpath
-Dmdep.outputFile=target/local-classpath.txt`; skip with `SKIP_BUILD=1`), starts `LocalDebugServer` on port 18081
(`REFERENCE_PORT`), sends each file through the REST flow (`POST /batches`, poll `GET /batches/{id}`, approve what
waits), and writes `reports/`, `outcome-<file>.txt`, `server.log`, `java-version.txt` and `hbase-sales_agg.txt`.

Reports written on Windows end lines with CRLF and on Linux with LF; the compare treats them as the same.
