#!/usr/bin/env bash
# Stop all local Nomad, Consul, and Vault processes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

stop_service() {
  local name=$1
  local pidfile="$LOG_DIR/${name}.pid"

  if [[ -f "$pidfile" ]]; then
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      log "Stopping $name (PID $pid)..."
      kill "$pid"
      local elapsed=0
      while kill -0 "$pid" 2>/dev/null; do
        sleep 0.5
        (( elapsed++ ))
        if (( elapsed > 20 )); then
          warn "Force-killing $name (PID $pid)..."
          kill -9 "$pid" 2>/dev/null || true
          break
        fi
      done
      log "$name stopped."
    else
      warn "$name PID $pid is not running."
    fi
    rm -f "$pidfile"
  else
    # Try killing by process name as fallback
    if pkill -f "${name} agent" 2>/dev/null; then
      log "$name stopped (by name)."
    else
      warn "$name is not running."
    fi
  fi
}

log "Stopping Nomad..."
stop_service nomad

log "Stopping Vault..."
stop_service vault

log "Stopping Consul..."
stop_service consul

log "All services stopped."
