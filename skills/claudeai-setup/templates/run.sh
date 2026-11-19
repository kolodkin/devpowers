#!/usr/bin/env bash
# Start (or stop) the local backing services. Each claudeai/setup_<svc>.sh is
# idempotent: it reuses a server already listening, installs into .cache/ when
# the binary is missing, then starts it. Processes do not survive a container
# suspend/resume, so run this at the start of each session.
#
# Usage:
#   claudeai/run.sh          # start all, in dependency order
#   claudeai/run.sh stop     # stop all, in reverse order
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/claudeai/_guard.sh"

# EDIT: one entry per claudeai/setup_<svc>.sh, dependencies first.
SERVICES=(__SERVICES__)

log() { printf '\033[32m[run]\033[0m %s\n' "$*"; }

if [ "${1:-}" = "stop" ]; then
  for ((i = ${#SERVICES[@]} - 1; i >= 0; i--)); do
    "$ROOT/claudeai/setup_${SERVICES[i]}.sh" stop || true   # keep stopping the rest
  done
  log "all services stopped"
  exit 0
fi

for svc in "${SERVICES[@]}"; do
  "$ROOT/claudeai/setup_$svc.sh"
done
log "all services up"
