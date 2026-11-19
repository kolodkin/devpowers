#!/usr/bin/env bash
# One-time install for the Claude Code web environment: project dependencies,
# then the backing services (installed under .cache/ and left running).
# Binaries and data under .cache/ survive a container suspend/resume; the
# processes don't. Use claudeai/run.sh to bring them back up.
#
# Usage:
#   claudeai/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/claudeai/_guard.sh"
cd "$ROOT"

log() { printf '\033[36m[setup]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[setup] error:\033[0m %s\n' "$*" >&2; exit 1; }

# EDIT: the dependency install CI runs before its tests, e.g.
#   command -v uv >/dev/null 2>&1 || die "uv not found"
#   log "installing deps"; uv sync --frozen
__PROJECT_DEPS__

"$ROOT/claudeai/run.sh"
log "done — use claudeai/run.sh to restart the services in a new session"
