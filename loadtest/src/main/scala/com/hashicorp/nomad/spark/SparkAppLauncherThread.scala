package com.hashicorp.nomad.spark

import java.io.File

import org.apache.spark.launcher.{ SparkAppHandle, SparkLauncher }

class SparkAppLauncherThread(
    logsDir: File,
    sparkArgs: Seq[(String, Option[String])],
    applicationResource: String,
    appId: String,
    onStateChange: SparkAppHandle.State => Unit
) extends Thread("launcher-" + appId) {

  private val launcher = new SparkLauncher()
  sparkArgs.foreach {
    case (arg, None) => launcher.addSparkArg(arg)
    case (arg, Some(value)) => launcher.addSparkArg(arg, value)
  }
  launcher
    .setConf("spark.app.id", appId)
    .setAppResource(applicationResource)
    .redirectOutput(new File(logsDir, s"$appId-stdout"))
    .redirectError(new File(logsDir, s"$appId-stderr"))

  val listener = new SparkAppHandle.Listener {
    override def infoChanged(handle: SparkAppHandle): Unit = {}
    override def stateChanged(handle: SparkAppHandle): Unit = onStateChange(handle.getState)
  }

  override def run(): Unit =
    try launcher.startApplication(listener)
    catch {
      case e: Throwable =>
        Console.err.println(s"EXCEPTION: " + e)
        e.printStackTrace()
        System.exit(1)
    }

}




