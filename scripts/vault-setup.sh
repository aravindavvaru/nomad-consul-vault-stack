#!/usr/bin/env bash
# Configure Vault policies and token roles for Nomad integration
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[VAULT-SETUP]${NC} $*"; }

# ── Enable secrets engine ──────────────────────────────────────────────────────
log "Enabling KV secrets engine at secret/..."
vault secrets enable -path=secret kv-v2 2>/dev/null || log "KV already enabled."

# ── Write example secrets ──────────────────────────────────────────────────────
log "Writing example secrets..."
vault kv put secret/web-app \
  db_password="changeme123" \
  api_key="dev-api-key-abc123"

vault kv put secret/database \
  host="127.0.0.1" \
  port="5432" \
  dbname="myapp" \
  username="appuser" \
  password="changeme123"

# ── Nomad server policy ────────────────────────────────────────────────────────
log "Creating Nomad server Vault policy..."
vault policy write nomad-server - <<'EOF'
# Allow Nomad server to create child tokens for jobs
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}
path "sys/capabilities-self" {
  capabilities = ["update"]
}
path "auth/token/renew" {
  capabilities = ["update"]
}
EOF

# ── Web app policy ─────────────────────────────────────────────────────────────
log "Creating web-app Vault policy..."
vault policy write web-app-policy - <<'EOF'
path "secret/data/web-app" {
  capabilities = ["read"]
}
path "secret/metadata/web-app" {
  capabilities = ["read"]
}
EOF

# ── DB backup policy ───────────────────────────────────────────────────────────
log "Creating db-backup Vault policy..."
vault policy write db-backup-policy - <<'EOF'
path "secret/data/database" {
  capabilities = ["read"]
}
path "secret/metadata/database" {
  capabilities = ["read"]
}
EOF

# ── Nomad cluster token role ───────────────────────────────────────────────────
log "Creating nomad-cluster token role..."
vault write auth/token/roles/nomad-cluster \
  name=nomad-cluster \
  period=259200 \
  renewable=true \
  allowed_policies="web-app-policy,db-backup-policy" \
  disallowed_policies="nomad-server" \
  explicit_max_ttl=0

# ── Create Nomad server token ──────────────────────────────────────────────────
log "Creating Nomad server token..."
NOMAD_VAULT_TOKEN=$(vault token create \
  -policy nomad-server \
  -period 259200 \
  -renewable true \
  -orphan \
  -format json | jq -r '.auth.client_token')

echo "$NOMAD_VAULT_TOKEN" > "$(dirname "$0")/../data/vault/nomad-token"
log "Nomad Vault token saved to data/vault/nomad-token"

export VAULT_TOKEN="$NOMAD_VAULT_TOKEN"
log "Vault setup complete. Use VAULT_TOKEN from data/vault/nomad-token when starting Nomad."
