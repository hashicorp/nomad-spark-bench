package com.hashicorp.nomad.spark

import java.io.{ File, FileOutputStream, PrintStream }

import com.hashicorp.nomad.spark.InternalLoadTestEvent._
import org.apache.spark.SparkConf
import org.apache.spark.scheduler._

class LoadTestEventListener(directory: File) extends SparkListener {

  def this(conf: SparkConf) =
    this(new File(conf.get("spark.nomad.executorCountDir")))

  var appId: Option[String] = None
  var fileStream: FileOutputStream = _
  var out: PrintStream = _

  def outputEvent(time: Long, details: InternalLoadTestEvent.Details): Unit =
    out.println(InternalLoadTestEvent(time, appId.get, details))

  override def onApplicationStart(applicationStart: SparkListenerApplicationStart): Unit = {
    fileStream = new FileOutputStream(new File(directory, applicationStart.appId.get + ".csv"))
    out = new PrintStream(fileStream)
    appId = applicationStart.appId
    outputEvent(applicationStart.time, ApplicationStart)
  }

  override def onExecutorAdded(executorAdded: SparkListenerExecutorAdded): Unit = {
    outputEvent(executorAdded.time, ExecutorStart(executorAdded.executorId))
  }

  override def onExecutorRemoved(executorRemoved: SparkListenerExecutorRemoved): Unit = {
    outputEvent(executorRemoved.time, ExecutorEnd(executorRemoved.executorId))
  }

//  override def onApplicationEnd(applicationEnd: SparkListenerApplicationEnd): Unit = {
//    outputEvent(applicationEnd.time, ApplicationEnd)
//    out.close()
//  }

  Runtime.getRuntime.addShutdownHook(new Thread() {
    override def run(): Unit = {
      outputEvent(System.currentTimeMillis(), ApplicationEnd)
      out.flush()
      fileStream.getFD.sync()
      out.close()
      System.err.println(s"LoadTestEventListener has written $ApplicationEnd event")
    }
  })

}
