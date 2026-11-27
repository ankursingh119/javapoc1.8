package com.example.salesbatch.spark

// Side-by-side harness for card SBJ17-11. Not part of the build: copy it into
// spark-job/src/test/scala/com/example/salesbatch/spark/ of a scratch copy (run.sh does).

import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Paths}

import com.example.salesbatch.common.RowKeys
import org.apache.spark.{SparkConf, SparkContext}
import org.junit.Test

import scala.collection.JavaConverters._

/**
 * For each CSV in $SBS_INPUTS it parses the rows inside Spark (as the job converts HBase rows on executors),
 * runs SalesAggregator.aggregate and writes, to $SBS_OUT/<input>.out, what writeAgg would put in sales_agg:
 * the row key and the three cell values, sorted by row key (HBase's order). Errors are written as their
 * root cause class and message (and six stack frames when SBS_STACK is set).
 */
class SbsHarnessTest {

  @Test def run(): Unit = {
    val inputs = Option(System.getenv("SBS_INPUTS")).getOrElse(return)
    val out = new File(System.getenv("SBS_OUT"))
    out.mkdirs()
    val sc = new SparkContext(new SparkConf().setMaster("local[2]").setAppName("sbs").set("spark.ui.enabled", "false"))
    try {
      new File(inputs).listFiles().filter(_.getName.endsWith(".csv")).sortBy(_.getName).foreach { f =>
        val text: Seq[String] = try {
          val lines = Files.readAllLines(f.toPath, StandardCharsets.UTF_8).asScala.drop(1)
          val raw = sc.parallelize(lines, 3).map { line =>
            val c = line.split(",", -1)
            RawSale("20261113", c(2), c(1), c(3).toLong, BigDecimal(c(4)))
          }
          val rows = SalesAggregator.aggregate(raw).collect().map { case ((d, r, p), a) =>
            RowKeys.agg(d, r, p) + "|" + a.totalQty.toString + "|" + a.totalAmount.bigDecimal.toPlainString + "|" + a.orderCount.toString
          }.sorted.toSeq
          ("rows=" + rows.length) +: rows
        } catch {
          case e: Throwable =>
            var root: Throwable = e
            while (root.getCause != null) root = root.getCause
            Seq("ERROR " + root.getClass.getName + ": " + root.getMessage) ++
              (if (System.getenv("SBS_STACK") != null) root.getStackTrace.take(6).map("  at " + _).toSeq else Seq.empty)
        }
        Files.write(Paths.get(out.getPath, f.getName + ".out"), (text.mkString("\n") + "\n").getBytes(StandardCharsets.UTF_8))
      }
    } finally {
      sc.stop()
    }
  }
}
