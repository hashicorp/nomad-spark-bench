/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.hashicorp.nomad.spark

import java.io.PrintStream

import scala.collection.mutable

import com.hashicorp.nomad.spark.InternalLoadTestEvent._
import org.apache.commons.io.IOUtils

class RunningTotals(events: Seq[InternalLoadTestEvent]) {

  def print(out: PrintStream): Unit = {

    var appsStarted = 0
    var appsFinished = 0

    var executorsStarted = 0
    var executorsFinished = 0

    var runningExecutorsByApp = mutable.Map[String, Int]()

    out.println(
      Seq(
        "time",
        "apps_started", "apps_running", "apps_finished",
        "executors_started", "executors_running", "executors_finished"
      ).mkString(",")
    )
    events
      .groupBy(_.time)
      .toSeq
      .sortBy(_._1)
      .foreach { case (time, eventsAtThisTime) =>
          eventsAtThisTime.foreach(e => e.details match {
            case ApplicationStart =>
              appsStarted += 1
              runningExecutorsByApp.put(e.appId, 0)
            case ApplicationEnd =>
              appsFinished += 1
              executorsFinished += runningExecutorsByApp(e.appId)
              runningExecutorsByApp -= e.appId
            case ExecutorStart(_) =>
              executorsStarted += 1
              runningExecutorsByApp.put(e.appId, runningExecutorsByApp(e.appId) + 1)
            case ExecutorEnd(_) =>
              executorsFinished += 1
              runningExecutorsByApp.put(e.appId, runningExecutorsByApp(e.appId) - 1)
          })
          out.println(
            Seq(
              time,
              appsStarted, runningExecutorsByApp.size, appsFinished,
              executorsStarted, runningExecutorsByApp.values.sum, executorsFinished
            ).mkString(",")
          )
      }
  }

}

object RunningTotals {

  def main(args: Array[String]): Unit = {
    import scala.collection.JavaConverters._

    val events =
      IOUtils.readLines(Console.in)
        .asScala
        .map(InternalLoadTestEvent.parse)

    new RunningTotals(events)
      .print(Console.out)
  }

}
