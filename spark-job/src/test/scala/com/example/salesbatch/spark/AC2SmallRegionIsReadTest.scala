package com.example.salesbatch.spark

import java.math.BigDecimal
import java.net.{InetSocketAddress, Socket}
import java.util.Arrays

import scala.collection.JavaConverters._

import com.example.salesbatch.common.{HBaseSalesRepository, RowKeys, SalesRecord, SalesSchema}
import org.apache.hadoop.hbase.TableName
import org.apache.hadoop.hbase.client.Delete
import org.apache.hadoop.hbase.util.Bytes
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.{After, Before, Test}

/**
 * Card SBJ17-11, AC2 (docs/cards/SBJ17-11.md, Plan): on Spark 3.2 and later, spark.hadoopRDD.ignoreEmptySplits is on
 * by default and drops every input split of length 0, and HBase 1.4's TableInputFormat gives a region with less than
 * 1 MB on disk a length of 0. Without the job turning the setting off, a small region's rows are never read and the
 * job ends with no error and a short or empty sales_agg.
 *
 * The existing SalesAggregatorHBaseTest covers rows still in the memstore; this test flushes sales_raw first, so the
 * rows sit in a store file far under 1 MB (sized 0 MB), and checks every row is aggregated by the real job
 * (SalesAggregator.main, local Spark). It needs HBase on localhost and is skipped otherwise; the pipeline's
 * scripts/spark35/acceptance AC1 and AC2 fail when it is skipped. Far-future dates, own rows deleted.
 */
class AC2SmallRegionIsReadTest {

  private val date = "20990201"
  private var repo: HBaseSalesRepository = _

  private def hbaseReachable(): Boolean = Seq(2181, 16000, 16020).forall { port =>
    val socket = new Socket()
    try {
      socket.connect(new InetSocketAddress("localhost", port), 500)
      true
    } catch {
      case _: Exception => false
    } finally {
      socket.close()
    }
  }

  @Before def setUp(): Unit = {
    assumeTrue("HBase is not running on localhost (2181, 16000, 16020), skipping", hbaseReachable())
    repo = new HBaseSalesRepository()
    repo.initSchema()
    cleanUp()
  }

  @After def tearDown(): Unit = {
    if (repo != null) {
      cleanUp()
      repo.close()
    }
  }

  private def cleanUp(): Unit = {
    val raw = repo.connection().getTable(TableName.valueOf(SalesSchema.RAW_TABLE))
    val agg = repo.connection().getTable(TableName.valueOf(SalesSchema.AGG_TABLE))
    try {
      repo.loadRaw(date).asScala.foreach(r => raw.delete(new Delete(Bytes.toBytes(RowKeys.raw(r.getDate, r.getOrderId)))))
      repo.loadAgg(date).asScala.foreach(a => agg.delete(new Delete(Bytes.toBytes(RowKeys.agg(a.getDate, a.getRegion, a.getProductId)))))
    } finally {
      raw.close()
      agg.close()
    }
  }

  private def runJob(businessDate: String): Unit = {
    System.setProperty("spark.master", "local[2]")
    System.setProperty("spark.ui.enabled", "false")
    try SalesAggregator.main(Array(businessDate))
    finally {
      System.clearProperty("spark.master")
      System.clearProperty("spark.ui.enabled")
    }
  }

  @Test(timeout = 180000) def flushedRegionUnderOneMegabyteIsReadInFull(): Unit = {
    // Order ids chosen to land in several salt buckets, so more than one region (when the table is split) is small.
    val orders = (1 to 12).map(i => new SalesRecord(date, "S" + i, "P" + (i % 3), "EU", i, new BigDecimal(i + ".25")))
    repo.saveRaw(Arrays.asList(orders: _*))
    val admin = repo.connection().getAdmin
    try admin.flush(TableName.valueOf(SalesSchema.RAW_TABLE))
    finally admin.close()
    assertEquals("the rows must be in sales_raw before the job", 12, repo.loadRaw(date).size)

    runJob(date)

    val rows = repo.loadAgg(date).asScala
    assertEquals("one aggregate per product, all 12 raw rows read", 3, rows.size)
    assertEquals(12L, rows.map(_.getOrderCount).sum)
    assertEquals((1 to 12).sum.toLong, rows.map(_.getTotalQty).sum)
    assertEquals(new BigDecimal("81.00"), rows.map(_.getTotalAmount).reduce(_ add _))
  }
}
