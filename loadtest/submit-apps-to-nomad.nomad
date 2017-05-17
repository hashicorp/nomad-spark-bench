job "submit-{{name}}" {
  datacenters = ["azure-eastus2"]
  type = "batch"
  group "spark-submit" {
    count = {{count}}
    task "spark-submit" {
      driver = "docker"
      env {
        HADOOP_CONF_DIR = "/opt/hadoop/etc/hadoop"
        SPARK_LOCAL_IP = "${NOMAD_IP_foo}"
      }
      config {
        image = "spark:load-test"
        args = [
          "/bin/bash", "-c", "sleep $((${NOMAD_ALLOC_INDEX} / 10 + 10)); \"$@\" $((${NOMAD_ALLOC_INDEX} * 13697 % 20000 + 90000))", "--",

          "/usr/local/spark/bin/spark-submit",
          "--master", "nomad",
          "--conf", "spark.nomad.executorCountDir=/internal-load-test-events",
          "--conf", "spark.nomad.datacenters=azure-eastus2",
          "--conf", "spark.nomad.job.template=/load-test-nomad-template.json",
          "--conf", "spark.app.id={{name}}-${NOMAD_ALLOC_INDEX}",
          "--docker-image", "spark:load-test",
          "--distribution", "local:///usr/local/spark",

          "--deploy-mode", "cluster",
          "--driver-memory", "1600m",
          "--executor-memory", "1600m",
          "--driver-class-path", "local:///spark-load-test.jar",
          "--conf", "spark.extraListeners=com.hashicorp.nomad.spark.LoadTestEventListener",
          "--num-executors", "{{executors}}",
          "--class", "org.apache.spark.examples.SparkPi",
          "local:///usr/local/spark/examples/jars/spark-examples_2.11-2.1.0.jar"
        ]
        volumes = [
          "/opt/hadoop:/opt/hadoop",
          "/load-test-nomad-template.json:/load-test-nomad-template.json"
        ]
        network_mode = "host"
      }
      resources {
        cpu    = 500
        memory = 1000
        network {
          mbits = 1
          port "foo" {}
        }
      }
    }
  }
}
