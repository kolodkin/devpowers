---
name: claudeai-run
description: Start the local backing services (__SERVICE_LIST__) that __TESTS__ need by running claudeai/run.sh. Use at the start of a new session, or whenever the services are down (e.g. after a container suspend/resume) and tests need them up.
---

# claudeai-run Skill

Brings up the local backing services. `claudeai/run.sh` calls one
`claudeai/setup_<svc>.sh` per service; each installs its binary and on-disk state
under `.cache/` when missing, then starts it. That state survives a container
resume, but the processes don't — so each session must run it again.

## Preflight: web environment only

These services are meant only for the Claude Code web (cloud) environment. Before
running anything, verify you're there — abort the skill if not:

```bash
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || { echo "Not the Claude Code web environment — skipping claudeai-run."; exit 1; }
```

`CLAUDE_CODE_REMOTE=true` is set only in the remote/web container (`CLAUDECODE=1`
is set for any Claude Code session, local included, so don't gate on that). The
`claudeai/*.sh` scripts enforce the same guard via `claudeai/_guard.sh`; a
deliberate local run can override with `CLAUDEAI_ALLOW_LOCAL=1`.

## Start

```bash
claudeai/run.sh
```

Idempotently starts (reusing anything already up, installing anything missing),
with the same credentials as the CI services in `__CI_FILE__`:

1. **__SVC__** — `:__PORT__` (__CREDENTIALS__)

Prints `[run] all services up` on success. A failure exits non-zero with a
`[<svc>] error:` line pointing at its log under `.cache/`.

## Use

```bash
__TEST_COMMAND__
```

## Stop

```bash
claudeai/run.sh stop   # reverse dependency order
```

## If a service won't start

Per-service logs: `.cache/<svc>.log`. To start over, stop the services, delete
that service's files under `.cache/`, then re-run `claudeai/run.sh`.
