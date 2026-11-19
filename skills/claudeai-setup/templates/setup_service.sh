#!/usr/bin/env bash
# Ensure a local __SVC__ server is available for __PURPOSE__.
#
# Reuses one already listening on $PORT. Otherwise installs it into .cache/
# (once) and starts a server in the background, left running. Safe to rerun.
#
# Usage:
#   claudeai/setup___SVC__.sh          # ensure a server is running
#   claudeai/setup___SVC__.sh stop     # stop the server this script started
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/claudeai/_guard.sh"
CACHE="$ROOT/.cache"
PORT=__PORT__
PIDFILE="$CACHE/__SVC__.pid"
LOG="$CACHE/__SVC__.log"

log() { printf '\033[35m[__SVC__]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[__SVC__] error:\033[0m %s\n' "$*" >&2; exit 1; }

# EDIT: prefer the service's own readiness probe (pg_isready, /ping, ...);
# an open TCP port only proves something is listening.
up() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; }

if [ "${1:-}" = "stop" ]; then
  if [ -s "$PIDFILE" ] && pid="$(cat "$PIDFILE")" && kill "$pid" 2>/dev/null; then
    # Wait for the exit, so a start right after does not see the dying server as up.
    for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
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
else
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

  for _ in $(seq 1 60); do up && break; sleep 1; done
  up || die "did not come up on :$PORT (see $LOG)"
  log "up on :$PORT (pid $(cat "$PIDFILE"))"
fi

# EDIT: idempotent post-start steps this service needs on every run (create a
# database or bucket, reset per-run state). Delete if there are none.
