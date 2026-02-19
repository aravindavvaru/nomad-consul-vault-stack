# Nomad + Consul + Vault — Local Dev Stack

A complete HashiCorp stack for local development: **Nomad** (workload orchestrator) + **Consul** (service mesh & discovery) + **Vault** (secrets management).

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Local Dev Machine                     │
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │  Consul  │◄───│  Nomad   │───►│      Vault       │  │
│  │  :8500   │    │  :4646   │    │      :8200       │  │
│  └──────────┘    └──────────┘    └──────────────────┘  │
│       │               │                                  │
│       │         ┌─────┴────────────────────────┐        │
│       │         │       Nomad Jobs              │        │
│       │         │  ┌────────┐  ┌────────────┐  │        │
│       └────────►│  │web-app │  │   redis    │  │        │
│                 │  └────────┘  └────────────┘  │        │
│                 │  ┌──────────┐ ┌───────────┐  │        │
│                 │  │db-backup │ │log-shipper│  │        │
│                 │  └──────────┘ └───────────┘  │        │
│                 └──────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Install with Homebrew on macOS:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/consul
brew install hashicorp/tap/vault
brew install hashicorp/tap/nomad
brew install jq nc  # utilities used by scripts
```

Verify versions:
```bash
consul version    # >= 1.17
vault version     # >= 1.15
nomad version     # >= 1.7
```

---

## Quick Start

### 1. Start all services

```bash
./scripts/start.sh
```

This will:
- Start Consul (`:8500`)
- Start Vault (`:8200`), initialize + unseal automatically
- Configure Vault policies and token roles for Nomad
- Start Nomad (`:4646`) with Consul + Vault integrations

### 2. Check status

```bash
./scripts/status.sh
```

### 3. Deploy example jobs

```bash
./scripts/deploy-jobs.sh
```

Or deploy a single job:
```bash
nomad job run jobs/service/redis.hcl
nomad job run jobs/service/web-app.hcl
```

### 4. Open UIs

| Service | URL |
|---------|-----|
| Nomad   | http://localhost:4646/ui |
| Consul  | http://localhost:8500/ui |
| Vault   | http://localhost:8200/ui |

### 5. Stop everything

```bash
./scripts/stop.sh
```

---

## Project Structure

```
nomad-project/
├── config/
│   ├── nomad/
│   │   └── server.hcl          # Nomad agent config (server + client)
│   ├── consul/
│   │   └── consul.hcl          # Consul agent config
│   └── vault/
│       └── vault.hcl           # Vault server config
├── jobs/
│   ├── service/
│   │   ├── web-app.hcl         # Long-running web service (Consul Connect)
│   │   └── redis.hcl           # Redis cache service
│   ├── batch/
│   │   └── db-backup.hcl       # Periodic backup job (Vault secrets)
│   └── system/
│       └── log-shipper.hcl     # System job (runs on all nodes)
├── scripts/
│   ├── start.sh                # Start full stack
│   ├── stop.sh                 # Stop full stack
│   ├── status.sh               # Show stack + job status
│   ├── vault-setup.sh          # Configure Vault policies/roles
│   └── deploy-jobs.sh          # Deploy all or specific jobs
├── policies/                   # Additional Vault policies (add your own)
├── data/                       # Runtime data (git-ignored)
│   ├── nomad/
│   ├── consul/
│   └── vault/
│       └── init.json           # Vault unseal key + root token (KEEP SECURE)
└── logs/                       # Service logs (git-ignored)
```

---

## Key Concepts

### Nomad Job Types

| Type | Use Case | Example |
|------|----------|---------|
| `service` | Long-running processes | Web app, Redis |
| `batch` | Run-to-completion tasks | DB backup, data processing |
| `system` | Run on every node | Log shipper, monitoring agent |
| `sysbatch` | System-scope batch | Node maintenance tasks |

### Vault Integration

Nomad tasks request Vault secrets via the `vault {}` block and `template {}` stanzas:

```hcl
task "app" {
  vault {
    policies = ["web-app-policy"]
  }

  template {
    data        = <<EOH
{{ with secret "secret/data/web-app" }}
DB_PASSWORD={{ .Data.data.db_password }}
{{ end }}
EOH
    destination = "secrets/.env"
    env         = true
  }
}
```

### Consul Service Mesh

Services use Consul Connect for mTLS communication:

```hcl
service {
  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "redis"
          local_bind_port  = 6379
        }
      }
    }
  }
}
```

---

## Common Commands

```bash
# Nomad
nomad job status                    # List all jobs
nomad job status web-app            # Job details
nomad alloc logs <alloc-id>         # View task logs
nomad alloc exec <alloc-id> /bin/sh # Shell into allocation
nomad job stop web-app              # Stop a job

# Consul
consul members                      # Show cluster members
consul catalog services             # List registered services
consul health service web-app       # Check service health

# Vault
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat data/vault/nomad-token)
vault kv get secret/web-app         # Read a secret
vault kv put secret/web-app key=val # Write a secret
vault token lookup                  # Check current token
```

---

## Security Notes

> These settings are for **local development only**.

For production:
- Enable ACLs in Nomad (`acl { enabled = true }`)
- Enable ACLs in Consul
- Enable TLS everywhere (Vault, Consul, Nomad)
- Use Vault auto-unseal (AWS KMS, Azure Key Vault, GCP Cloud KMS)
- Never store `data/vault/init.json` in version control
- Use dedicated Vault token per service, not the root token

---

## .gitignore

```
data/
logs/
*.pid
```
