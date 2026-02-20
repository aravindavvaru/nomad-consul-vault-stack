#!/usr/bin/env bash
# Deploy Nomad jobs
set -euo pipefail

export NOMAD_ADDR="${NOMAD_ADDR:-http://127.0.0.1:4646}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JOBS_DIR="$PROJECT_DIR/jobs"
NOMAD_TOKEN_FILE="$PROJECT_DIR/data/vault/nomad-token"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
log()  { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC}  $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ── Load Vault token if available ─────────────────────────────────────────────
VAULT_ENABLED=false
if [[ -z "${VAULT_TOKEN:-}" ]] && [[ -f "$NOMAD_TOKEN_FILE" ]]; then
  export VAULT_TOKEN
  VAULT_TOKEN=$(cat "$NOMAD_TOKEN_FILE")
  log "Loaded Vault token from $NOMAD_TOKEN_FILE"
fi

if nc -z 127.0.0.1 8200 2>/dev/null && [[ -n "${VAULT_TOKEN:-}" ]]; then
  VAULT_ENABLED=true
  log "Vault is reachable — vault-dependent jobs will be deployed."
else
  warn "Vault is not running or VAULT_TOKEN is not set."
  warn "Jobs that use 'vault {}' blocks will be skipped."
  warn "Start Vault first with: ./scripts/start.sh"
fi

# Jobs that require Vault
VAULT_JOBS=(
  "$JOBS_DIR/service/web-app.hcl"
  "$JOBS_DIR/batch/db-backup.hcl"
)

needs_vault() {
  local jobfile=$1
  for vj in "${VAULT_JOBS[@]}"; do
    [[ "$vj" == "$jobfile" ]] && return 0
  done
  return 1
}

# ── Deploy function ───────────────────────────────────────────────────────────
deploy_job() {
  local jobfile=$1
  local jobname
  jobname=$(basename "$jobfile" .hcl)

  if needs_vault "$jobfile" && [[ "$VAULT_ENABLED" == "false" ]]; then
    warn "Skipping $jobname — requires Vault (not available)."
    return 0
  fi

  log "Validating $jobname..."
  if ! nomad job validate "$jobfile"; then
    err "Validation failed for $jobfile"
    return 1
  fi

  log "Deploying $jobname..."
  nomad job run "$jobfile"
  log "$jobname deployed."
}

# ── Deploy order: infra → services → system → batch ──────────────────────────
DEPLOY_ORDER=(
  "$JOBS_DIR/service/redis.hcl"
  "$JOBS_DIR/service/web-app.hcl"
  "$JOBS_DIR/system/log-shipper.hcl"
  "$JOBS_DIR/batch/db-backup.hcl"
)

if [[ $# -gt 0 ]]; then
  for jobfile in "$@"; do
    deploy_job "$jobfile"
  done
else
  for jobfile in "${DEPLOY_ORDER[@]}"; do
    if [[ -f "$jobfile" ]]; then
      deploy_job "$jobfile"
    else
      log "Skipping missing job file: $jobfile"
    fi
  done
fi

log "Done. Check status:"
echo "  nomad job status"
echo "  nomad job status web-app"
echo "  open http://localhost:4646/ui"
