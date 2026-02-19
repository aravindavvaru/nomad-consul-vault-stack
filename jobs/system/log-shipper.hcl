# Example: System job — runs on every Nomad client node
# Ships logs to a central aggregator (e.g., Loki, Elasticsearch)

job "log-shipper" {
  datacenters = ["dc1"]
  type        = "system"

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
  }

  group "log-shipper" {
    restart {
      attempts = 5
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    network {
      mode = "host"

      port "metrics" {
        static = 2112
      }
    }

    service {
      name = "log-shipper"
      port = "metrics"
      tags = ["monitoring", "logs"]

      check {
        type     = "http"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "filebeat" {
      driver = "docker"

      config {
        image        = "elastic/filebeat:8.11.0"
        network_mode = "host"
        user         = "root"

        volumes = [
          "/var/lib/docker/containers:/var/lib/docker/containers:ro",
          "/var/log:/var/log:ro",
          "local/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro",
        ]
      }

      template {
        data = <<EOH
filebeat.inputs:
  - type: container
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"

  - type: log
    paths:
      - /var/log/nomad*.log

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]
  index: "nomad-logs-%{+yyyy.MM.dd}"

logging.level: info
logging.to_files: true
EOH
        destination = "local/filebeat.yml"
        change_mode = "restart"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
