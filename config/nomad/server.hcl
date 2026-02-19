# Nomad Server Configuration (Dev/Local)
# Runs as both server and client for local development

data_dir  = "/Users/aravindavvaru/nomad-project/data/nomad"
log_level = "INFO"
log_file  = "/Users/aravindavvaru/nomad-project/logs/nomad.log"

bind_addr = "0.0.0.0"

advertise {
  http = "127.0.0.1"
  rpc  = "127.0.0.1"
  serf = "127.0.0.1"
}

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled = true
  servers = ["127.0.0.1:4647"]

  host_volume "local-data" {
    path      = "/tmp/nomad-volumes"
    read_only = false
  }
}

# Consul integration
consul {
  address = "127.0.0.1:8500"
  token   = "" # Set CONSUL_HTTP_TOKEN env var if ACLs enabled

  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise      = true
  server_auto_join    = true
  client_auto_join    = true
}

# Vault integration
vault {
  enabled = true
  address = "http://127.0.0.1:8200"

  # Token used by Nomad server to create child tokens for jobs
  # Set VAULT_TOKEN env var or use token = "..."
  create_from_role = "nomad-cluster"
}

telemetry {
  collection_interval        = "1s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

ui {
  enabled = true

  consul {
    ui_url = "http://localhost:8500/ui"
  }

  vault {
    ui_url = "http://localhost:8200/ui"
  }
}

acl {
  enabled = false # Enable in production
}
