# Vault Server Configuration (Dev/Local)

storage "file" {
  path = "/Users/aravindavvaru/nomad-project/data/vault"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true # TLS disabled for local dev — enable in production!
}

api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"

ui = true

# Telemetry
telemetry {
  disable_hostname          = true
  prometheus_retention_time = "24h"
}

# Logging
log_level = "info"
log_file  = "/Users/aravindavvaru/nomad-project/logs/vault.log"

# Seal configuration (auto-unseal disabled for local dev)
# In production, use AWS KMS, GCP Cloud KMS, or Azure Key Vault

# Plugin directory
plugin_directory = "/Users/aravindavvaru/nomad-project/data/vault/plugins"
