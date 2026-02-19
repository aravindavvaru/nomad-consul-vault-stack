# Example: Redis as a Consul-registered service

job "redis" {
  datacenters = ["dc1"]
  type        = "service"

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
  }

  group "redis" {
    count = 1

    restart {
      attempts = 5
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "bridge"

      port "redis" {
        to     = 6379
        static = 6379
      }
    }

    service {
      name = "redis"
      port = "redis"
      tags = ["cache", "redis"]

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }

      connect {
        sidecar_service {}
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image   = "redis:7-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args    = ["--save", "60", "1", "--loglevel", "warning"]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }
  }
}
