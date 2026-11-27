# SBJ17-11 side-by-side harness

Kept beside the card file so Verify can run it again (card file: `../SBJ17-11.md`, section Assess).

1. Two scratch clones of the repository: `old` (main) and `new` (the card's head, or for Assess main with
   `spark.version` 3.5.5, `scala.version` 2.12.18, `scala.binary.version` 2.12).
2. `python -I make_inputs.py <scratch>/inputs <repository>/sample-data` writes the 34 inputs.
3. For each side, one after the other (never both at once: they share `~/.m2` and ports), on JDK 8 with
   `SPARK_LOCAL_IP=127.0.0.1`: copy `SbsHarnessTest.scala` into `spark-job/src/test/scala/com/example/salesbatch/spark/`,
   then for each environment (none; `-Dfile.encoding=ISO-8859-1`;
   `-Duser.language=ar -Duser.country=SA -Duser.timezone=Asia/Kolkata`, given in `JAVA_TOOL_OPTIONS`):
   `SBS_INPUTS=<scratch>/inputs SBS_OUT=<scratch>/out/<side>/<env> mvn -B -pl common,spark-job -Dtest=SbsHarnessTest -DfailIfNoTests=false test`
4. Compare `out/old/<env>/<input>.out` with `out/new/<env>/<input>.out`; ignore lines starting with `  at `
   (stack frames, set only when `SBS_STACK` is set).

Assess result (2026-11-27): 34 inputs x 3 environments, 0 differences.
The HBase half of the job is not in this harness: the pipeline's HBase end-to-end test and the reference compare cover it.
