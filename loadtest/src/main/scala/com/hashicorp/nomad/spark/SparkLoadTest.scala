package com.hashicorp.nomad.spark

import java.io.File
import java.nio.charset.StandardCharsets.UTF_8
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.CountDownLatch

import org.apache.commons.io.FileUtils
import org.apache.spark.launcher.SparkAppHandle

class SparkLoadTest {

  def run(
      launcherLogsDir: File,
      sparkArgs: Seq[(String, Option[String])],
      applicationResource: String,
      baseAppId: String,
      applications: Int
  ): Unit = {

    val applicationsComplete = new CountDownLatch(applications)

    // Spawn threads to launch initial applications
    (0 until applications).map { index =>
      val appId = s"$baseAppId-$index"
      new SparkAppLauncherThread(launcherLogsDir, sparkArgs, applicationResource, appId, { state: SparkAppHandle.State =>
        println(s"${System.currentTimeMillis()},$appId,$state")
        if (state.isFinal) {
          applicationsComplete.countDown()
        }

      })
    }.foreach(_.start())

    applicationsComplete.await()
  }

}

object SparkLoadTest {

  def main(args: Array[String]): Unit = {

    if (args.length != 4) {
      System.err.println("usage: SparkLoadTest <launcher-logs-dir> <spark-submit-args-file> <base-app-id> <app-count>")
      System.exit(2)
    }

    val (sparkArgs, applicationResource) = loadSparkArgsAndResource(new File(args(1)))

    new SparkLoadTest().run(
      launcherLogsDir = new File(args(0)),
      sparkArgs = sparkArgs,
      applicationResource = applicationResource,
      baseAppId = args(2),
      applications = args(3).toInt
    )
  }

  def loadSparkArgsAndResource(file: File): (Seq[(String, Option[String])], String) = {
    import scala.collection.JavaConverters._
    val args :+ ((resource, None)) = FileUtils.readLines(file, UTF_8).asScala
      .map(_.split(" ") match {
        case Array(arg) => arg -> None
        case Array(arg, value) => arg -> Some(value)
      })
    (args, resource)
  }

}
