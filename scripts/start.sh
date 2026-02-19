#!/usr/bin/env bash
# Start Consul, Vault, and Nomad for local development
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_binary() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 is not installed. Install it with: brew install $1"
    exit 1
  fi
}

wait_for_port() {
  local name=$1 port=$2 timeout=${3:-30}
  local elapsed=0
  while ! nc -z 127.0.0.1 "$port" 2>/dev/null; do
    if (( elapsed >= timeout )); then
      err "$name did not start on port $port within ${timeout}s"
      return 1
    fi
    sleep 1
    (( elapsed++ ))
  done
  log "$name is up on port $port"
}

# ── Pre-flight checks ──────────────────────────────────────────────────────────
log "Checking required binaries..."
check_binary consul
check_binary vault
check_binary nomad

mkdir -p "$LOG_DIR" "$DATA_DIR/consul" "$DATA_DIR/vault" "$DATA_DIR/nomad"
mkdir -p /tmp/nomad-volumes

# ── Start Consul ───────────────────────────────────────────────────────────────
log "Starting Consul..."
if pgrep -f "consul agent" > /dev/null; then
  warn "Consul is already running, skipping."
else
  consul agent \
    -config-file="$PROJECT_DIR/config/consul/consul.hcl" \
    > "$LOG_DIR/consul.log" 2>&1 &
  echo $! > "$LOG_DIR/consul.pid"
  wait_for_port "Consul" 8500
fi

# ── Start Vault ────────────────────────────────────────────────────────────────
log "Starting Vault..."
if pgrep -f "vault server" > /dev/null; then
  warn "Vault is already running, skipping."
else
  vault server \
    -config="$PROJECT_DIR/config/vault/vault.hcl" \
    > "$LOG_DIR/vault.log" 2>&1 &
  echo $! > "$LOG_DIR/vault.pid"
  wait_for_port "Vault" 8200

  # Initialize Vault if not already initialized
  export VAULT_ADDR="http://127.0.0.1:8200"
  if ! vault status 2>/dev/null | grep -q "Initialized.*true"; then
    log "Initializing Vault..."
    vault operator init \
      -key-shares=1 \
      -key-threshold=1 \
      -format=json > "$DATA_DIR/vault/init.json"
    log "Vault init keys saved to: $DATA_DIR/vault/init.json"
    warn "IMPORTANT: Back up $DATA_DIR/vault/init.json securely!"
  fi

  # Auto-unseal if init.json exists
  if [[ -f "$DATA_DIR/vault/init.json" ]]; then
    UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "$DATA_DIR/vault/init.json")
    ROOT_TOKEN=$(jq -r '.root_token' "$DATA_DIR/vault/init.json")
    vault operator unseal "$UNSEAL_KEY" > /dev/null
    log "Vault unsealed."
    export VAULT_TOKEN="$ROOT_TOKEN"
    log "VAULT_TOKEN set from init.json"
  fi
fi

# ── Setup Vault for Nomad ──────────────────────────────────────────────────────
if [[ -n "${VAULT_TOKEN:-}" ]]; then
  log "Configuring Vault policies and roles for Nomad..."
  bash "$SCRIPT_DIR/vault-setup.sh" || warn "Vault setup had errors (may already be configured)"
fi

# ── Start Nomad ────────────────────────────────────────────────────────────────
log "Starting Nomad..."
if pgrep -f "nomad agent" > /dev/null; then
  warn "Nomad is already running, skipping."
else
  VAULT_TOKEN="${VAULT_TOKEN:-}" nomad agent \
    -config="$PROJECT_DIR/config/nomad/server.hcl" \
    > "$LOG_DIR/nomad.log" 2>&1 &
  echo $! > "$LOG_DIR/nomad.pid"
  wait_for_port "Nomad" 4646
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
log "All services started successfully!"
echo ""
echo "  Nomad  UI: http://localhost:4646/ui"
echo "  Consul UI: http://localhost:8500/ui"
echo "  Vault  UI: http://localhost:8200/ui"
echo ""
echo "  Logs:  $LOG_DIR/"
echo "  PIDs:  $LOG_DIR/*.pid"
echo ""
echo "  Stop all services: ./scripts/stop.sh"
