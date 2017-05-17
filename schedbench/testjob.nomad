job "classlogger-docker" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  priority    = 50

  group "classlogger-1" {
    count = 1

    restart {
      mode     = "fail"
      attempts = 3
      interval = "5m"
      delay    = "2s"
    }

    task "classlogger-1" {
      driver = "docker"

      config {
        image        = "redis"
        args         = [ "--port", "12345" ]
        network_mode = "host"
      }

      resources {
        cpu    = 20
        memory = 15
        disk   = 10
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      env {
        REDIS_ADDR = "redis.service.consul:6379"
        NODE_CLASS = "${node.class}"
      }
    }
  }

  group "classlogger-2" {
    count = 1

    restart {
      mode     = "fail"
      attempts = 3
      interval = "5m"
      delay    = "2s"
    }

    task "classlogger-2" {
      driver = "docker"

      config {
        image        = "redis"
        args         = [ "--port", "12346" ]
        network_mode = "host"
      }

      resources {
        cpu    = 20
        memory = 15
        disk   = 10
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      env {
        REDIS_ADDR = "redis.service.consul:6379"
        NODE_CLASS = "${node.class}"
      }
    }
  }

  group "classlogger-3" {
    count = 1

    restart {
      mode     = "fail"
      attempts = 3
      interval = "5m"
      delay    = "2s"
    }

    task "classlogger-3" {
      driver = "docker"

      config {
        image        = "redis"
        args         = [ "--port", "12347" ]
        network_mode = "host"
      }

      resources {
        cpu    = 20
        memory = 15
        disk   = 10
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      env {
        REDIS_ADDR = "redis.service.consul:6379"
        NODE_CLASS = "${node.class}"
      }
    }
  }

  group "classlogger-4" {
    count = 1

    restart {
      mode     = "fail"
      attempts = 3
      interval = "5m"
      delay    = "2s"
    }

    task "classlogger-4" {
      driver = "docker"

      config {
        image        = "redis"
        args         = [ "--port", "12348" ]
        network_mode = "host"
      }

      resources {
        cpu    = 20
        memory = 15
        disk   = 10
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      env {
        REDIS_ADDR = "redis.service.consul:6379"
        NODE_CLASS = "${node.class}"
      }
    }
  }

  group "classlogger-5" {
    count = 1

    restart {
      mode     = "fail"
      attempts = 3
      interval = "5m"
      delay    = "2s"
    }

    task "classlogger-5" {
      driver = "docker"

      config {
        image        = "redis"
        args         = [ "--port", "12349" ]
        network_mode = "host"
      }

      resources {
        cpu    = 20
        memory = 15
        disk   = 10
      }

      logs {
        max_files     = 1
        max_file_size = 5
      }

      env {
        REDIS_ADDR = "redis.service.consul:6379"
        NODE_CLASS = "${node.class}"
      }
    }
  }
}
