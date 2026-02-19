# Example: Long-running web application service job
# Registers with Consul, reads secrets from Vault

job "web-app" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "default"

  # Update strategy for zero-downtime deployments
  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    canary            = 0
  }

  # Reschedule on failure
  reschedule {
    delay          = "30s"
    delay_function = "exponential"
    max_delay      = "10m"
    unlimited      = true
  }

  group "web" {
    count = 2

    # Restart policy
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    # Consul service mesh (Connect sidecar)
    network {
      mode = "bridge"

      port "http" {
        to = 8080
      }
    }

    service {
      name = "web-app"
      port = "http"
      tags = ["traefik.enable=true", "urlprefix-/web"]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "redis"
              local_bind_port  = 6379
            }
            upstreams {
              destination_name = "postgres"
              local_bind_port  = 5432
            }
          }
        }
      }
    }

    task "web" {
      driver = "docker"

      # Pull secrets from Vault
      vault {
        policies = ["web-app-policy"]
      }

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      # Template pulls secrets from Vault dynamically
      template {
        data = <<EOH
{{- with secret "secret/data/web-app" -}}
DB_PASSWORD={{ .Data.data.db_password }}
API_KEY={{ .Data.data.api_key }}
{{- end }}
REDIS_HOST={{ env "NOMAD_UPSTREAM_ADDR_redis" }}
EOH
        destination = "secrets/.env"
        env         = true
        change_mode = "restart"
      }

      # Register service with Consul via template
      template {
        data = <<EOH
server {
  listen 8080;
  location /health { return 200 'OK'; add_header Content-Type text/plain; }
  location / { root /usr/share/nginx/html; }
}
EOH
        destination = "local/nginx.conf"
        change_mode = "signal"
        change_signal = "SIGHUP"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
