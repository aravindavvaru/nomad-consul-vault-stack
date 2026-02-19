#!/usr/bin/env bash
# Deploy Nomad jobs
set -euo pipefail

export NOMAD_ADDR="${NOMAD_ADDR:-http://127.0.0.1:4646}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$(dirname "$SCRIPT_DIR")/jobs"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC}  $*" >&2; }

deploy_job() {
  local jobfile=$1
  local jobname
  jobname=$(basename "$jobfile" .hcl)

  log "Validating $jobname..."
  if ! nomad job validate "$jobfile"; then
    err "Validation failed for $jobfile"
    return 1
  fi

  log "Deploying $jobname..."
  nomad job run "$jobfile"
  log "$jobname deployed."
}

# Deploy in order: infrastructure first, then services, then batch
DEPLOY_ORDER=(
  "$JOBS_DIR/service/redis.hcl"
  "$JOBS_DIR/service/web-app.hcl"
  "$JOBS_DIR/system/log-shipper.hcl"
  "$JOBS_DIR/batch/db-backup.hcl"
)

if [[ $# -gt 0 ]]; then
  # Deploy specific jobs passed as arguments
  for jobfile in "$@"; do
    deploy_job "$jobfile"
  done
else
  # Deploy all jobs in order
  for jobfile in "${DEPLOY_ORDER[@]}"; do
    if [[ -f "$jobfile" ]]; then
      deploy_job "$jobfile"
    else
      log "Skipping missing job file: $jobfile"
    fi
  done
fi

log "All jobs deployed. Check status:"
echo "  nomad job status"
echo "  nomad job status web-app"
echo "  open http://localhost:4646/ui"
