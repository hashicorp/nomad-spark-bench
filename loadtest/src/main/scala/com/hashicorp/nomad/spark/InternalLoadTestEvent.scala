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

import com.hashicorp.nomad.spark.InternalLoadTestEvent.Details

/** An event detected from inside a load test Spark application */
case class InternalLoadTestEvent(
    time: Long,
    appId: String,
    details: Details
) {
  override def toString: String =
    productIterator.mkString(",")
}

object InternalLoadTestEvent {

  sealed trait Details { _: Product =>
    override def toString: String =
      (getClass.getSimpleName.stripSuffix("$") +: productIterator.toSeq).mkString(",")
  }
  case object ApplicationStart extends Details
  case object ApplicationEnd extends Details
  case class ExecutorStart(executorId: String) extends Details
  case class ExecutorEnd(executorId: String) extends Details

  def parse(event: String): InternalLoadTestEvent = {
    val (Seq(time, appId), details) = event.split(",").toSeq.splitAt(2)
    InternalLoadTestEvent(time.toLong, appId, details match {
      case Seq("ApplicationStart") => ApplicationStart
      case Seq("ApplicationEnd") => ApplicationEnd
      case Seq("ExecutorStart", id) => ExecutorStart(id)
      case Seq("ExecutorEnd", id) => ExecutorEnd(id)
    })
  }

}
