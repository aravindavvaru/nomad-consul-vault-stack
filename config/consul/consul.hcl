# Consul Agent Configuration (Dev/Local)

datacenter = "dc1"
data_dir   = "/Users/aravindavvaru/nomad-project/data/consul"
log_level  = "INFO"
log_file   = "/Users/aravindavvaru/nomad-project/logs/consul.log"

node_name = "nomad-local"

bind_addr    = "127.0.0.1"
client_addr  = "0.0.0.0"
advertise_addr = "127.0.0.1"

ports {
  http  = 8500
  https = -1
  grpc  = 8502
  dns   = 8600
}

server           = true
bootstrap_expect = 1

ui_config {
  enabled = true
}

# Enable service mesh (Connect)
connect {
  enabled = true
}

# DNS configuration
dns_config {
  allow_stale    = true
  max_stale      = "87600h"
  service_ttl    = { "*" = "5s" }
  node_ttl       = "5s"
  enable_truncate = true
}

# ACL (disabled for local dev)
acl {
  enabled                  = false
  default_policy           = "allow"
  enable_token_persistence = true
}

# Performance tuning for local dev
performance {
  raft_multiplier = 1
}

# Health check defaults
checks_use_advertise = false
