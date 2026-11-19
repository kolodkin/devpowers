---
name: claudeai-run-setup
description: Use when a project needs its backing services (databases, object stores, queues, daemons) runnable inside the Claude Code web (cloud) container, where Docker is unavailable - e.g. "/claudeai-run-setup", "set up claudeai-run", "add redis to claudeai", "make the CI services run in the cloud session", or tests fail there because a service CI provides is missing.
---

# claudeai-run-setup

Scaffolds a project's `claudeai/` scripts and its project-level `claudeai-run`
skill, so a cloud session can start the services CI gets from Docker.

## Arguments

```
/claudeai-run-setup [service ...]
```

- **service** (optional, repeatable) — services to set up. Omitted: derive
  them from the project's CI (step 1).

## What it produces

| File                                 | From template                   | Role                                             |
|--------------------------------------|---------------------------------|--------------------------------------------------|
| `claudeai/_guard.sh`                 | `templates/_guard.sh` (as is)   | Refuses to run outside the web container         |
| `claudeai/setup_<svc>.sh`            | `templates/setup_service.sh`    | One per service: reuse, install, start, `stop`   |
| `claudeai/run.sh`                    | `templates/run.sh`              | Start all in order, `stop` in reverse            |
| `claudeai/setup.sh`                  | `templates/setup.sh`            | Project deps, then `run.sh`                      |
| `.claude/skills/claudeai-run/SKILL.md` | `templates/claudeai-run.SKILL.md` | Tells future sessions how to start and use them |

Keep this shape. Each template marks its project-specific parts with `# EDIT:`
and `__PLACEHOLDER__`; change those and leave the rest.

## 1. Find the services

- If `claudeai/` already exists, read it and only add or fix what is asked.
  Never regenerate working scripts.
- Services named by the user win. Otherwise read the CI the tests run under:
  `services:` blocks and composite actions in `.github/workflows/`, and any
  `docker-compose*.y*ml` the workflows use.
- Per service, record: image and **version**, port, credentials, databases or
  buckets created, and the env vars the tests read to reach it.
- No CI, or it is unclear which services the tests need: ask the user, one
  question.

## 2. Pick an install method per service

The web container has no Docker daemon, and runs as root. In order of
preference:

1. Already installed — check with `command -v` and e.g.
   `ls /usr/lib/postgresql/*/bin`.
2. A standalone binary or tarball from the vendor, into `.cache/<svc>/`.
3. `apt-get install` (run `apt-get update` first: a fresh container has an
   empty package list).
4. Build from source, only when nothing is published.

Fetch the download URL once before writing it into a script. A blocked host
is the environment's network policy: tell the user which host to allow, do
not work around it.

## 3. Write the scripts

Copy the templates into `claudeai/`, fill them in, `chmod +x` all but
`_guard.sh`. Per service, match CI: same version, port, credentials.

- **Server refuses to run as root** (Postgres, MySQL): run it as its system
  user with `runuser -u <user> --`, and `chown` its data dir and log.
- **Server forks or daemonizes**: the pid recorded by the template is then
  the launcher's. Disable forking, or use the server's own pid file and stop
  command.
- **Port clashes between services**: move one and say so in a comment.
- **Per-run state** (an empty repo, a fresh bucket): recreate it before the
  "already up" early exit, so every `run.sh` resets it.
- **One-off steps after start** (migrations, create a database or bucket):
  put them at the end of that service's script, idempotent.
- **Tests need connection env vars**: add `claudeai/env.sh` with `export`
  lines mirroring CI, and have the project skill say to `source` it.

Add `.cache/` to `.gitignore`.

## 4. Verify

```bash
claudeai/setup.sh          # installs, ends with "[run] all services up"
claudeai/run.sh stop
claudeai/run.sh            # restarts from the installed state, no downloads
claudeai/run.sh            # second run: every service "already up"
```

Then run one test that needs the services, the way CI runs it. Report any
step that did not pass with its `.cache/<svc>.log` output; do not write the
project skill for services that never came up.

## 5. Write the project skill

Fill `templates/claudeai-run.SKILL.md` into
`.claude/skills/claudeai-run/SKILL.md`: one numbered line per service with
its port and credentials, and the exact test command from step 4.
