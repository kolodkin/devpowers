#!/usr/bin/env bash
# Ensure a local __SVC__ server is available for __PURPOSE__.
#
# Reuses one already listening on $PORT. Otherwise installs it into .cache/
# (once) and starts a server in the background, left running. Safe to rerun.
#
# Usage:
#   claudeai/setup___SVC__.sh          # ensure a server is running
#   claudeai/setup___SVC__.sh stop     # stop the server this script started
#
# Env: __PORT_VAR__ (default __PORT__)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/claudeai/_guard.sh"
CACHE="$ROOT/.cache"
PORT="${__PORT_VAR__:-__PORT__}"
PIDFILE="$CACHE/__SVC__.pid"
LOG="$CACHE/__SVC__.log"

log() { printf '\033[35m[__SVC__]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[__SVC__] error:\033[0m %s\n' "$*" >&2; exit 1; }

# EDIT: prefer the service's own readiness probe (pg_isready, /ping, ...);
# an open TCP port only proves something is listening.
up() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; }

if [ "${1:-}" = "stop" ]; then
  if [ -s "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; then
    log "stopped"
  else
    log "nothing to stop"
  fi
  rm -f "$PIDFILE"
  exit 0
fi

mkdir -p "$CACHE"

if up; then
  log "already up on :$PORT"
  exit 0
fi

# EDIT: install once, guarded by a check for the binary / data dir, pinned to
# the version CI runs. Everything lands under $CACHE.
__INSTALL__

log "starting on :$PORT"
# setsid detaches the server from this shell's session and the stdio redirects
# drop every inherited fd, so it survives this script exiting and never holds
# open a pipe the caller is reading from. exec keeps $! the server's own pid.
# EDIT: the server command, with the credentials CI's service uses.
(
  cd "$CACHE"
  exec setsid __START_CMD__ </dev/null >"$LOG" 2>&1
) &
echo $! > "$PIDFILE"
disown 2>/dev/null || true

for _ in $(seq 1 60); do
  if up; then
    log "up on :$PORT (pid $(cat "$PIDFILE"))"
    exit 0
  fi
  sleep 1
done
die "did not come up on :$PORT (see $LOG)"
