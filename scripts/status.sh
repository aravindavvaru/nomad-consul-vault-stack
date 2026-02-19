#!/usr/bin/env bash
# Show status of all stack components
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$SCRIPT_DIR")/logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

check_service() {
  local name=$1 port=$2 ui_url=$3
  if nc -z 127.0.0.1 "$port" 2>/dev/null; then
    echo -e "  ${GREEN}●${NC} ${BOLD}${name}${NC} — running on :${port}  ${YELLOW}${ui_url}${NC}"
  else
    echo -e "  ${RED}●${NC} ${BOLD}${name}${NC} — NOT running"
  fi
}

echo ""
echo -e "${BOLD}=== Stack Status ===${NC}"
check_service "Consul" 8500 "http://localhost:8500/ui"
check_service "Vault"  8200 "http://localhost:8200/ui"
check_service "Nomad"  4646 "http://localhost:4646/ui"
echo ""

if nc -z 127.0.0.1 4646 2>/dev/null; then
  echo -e "${BOLD}=== Nomad Jobs ===${NC}"
  nomad job status 2>/dev/null || echo "  (no jobs running)"
  echo ""
  echo -e "${BOLD}=== Nomad Nodes ===${NC}"
  nomad node status 2>/dev/null || true
fi

if nc -z 127.0.0.1 8500 2>/dev/null; then
  echo ""
  echo -e "${BOLD}=== Consul Services ===${NC}"
  consul catalog services 2>/dev/null || true
fi
