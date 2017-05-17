name := "spark-load-test"
description := "Repeatedly invokes spark-submit to run many instances of an application"

scalaVersion := "2.11.8"

unmanagedBase :=
  file(
    sys.props.get("spark.home")
      .orElse(sys.env.get("SPARK_HOME"))
      .getOrElse(sys.error("spark.home property or SPARK_HOME environment variable must be set"))) /
    "jars"

mainClass in Compile := Some("com.hashicorp.nomad.spark.SparkLoadTest")
