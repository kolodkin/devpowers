---
name: remote-docker-debug
description: Debug Docker containers running on a remote VM via SSH. Use when the user wants to discover running containers, tail remote docker logs, or troubleshoot deployed services on a remote host. Triggers on mentions of "remote docker logs", "prod debug", "tail container logs", "what's running on <host>", or debugging containers on a deployed VM.
---

# Remote Docker Debugging

Discover and tail logs for Docker containers on a remote VM over SSH.

## Arguments

```
/remote-docker-debug <ssh-host> [container-name ...]
```

- **ssh-host** (required) — SSH host name as configured in `~/.ssh/config`
- **container-name** (optional, repeatable) — One or more container names or IDs to tail. If omitted, run the discovery phase and ask the user which containers to tail.

## IMPORTANT

This skill is strictly read-only on the remote VM. NEVER run `docker exec`, `docker build`, `docker compose up/down`, `docker run`, `docker rm`, `docker stop`, `docker restart`, or any command that modifies container or host state. Only the following are allowed:

- `docker ps` (and variants with `--format`, `-a`, `--filter`)
- `docker logs` (with `--tail`, `--since`, `-f`)
- `docker inspect` (read-only metadata)
- `ssh -G` for host resolution
- `curl` for connectivity checks against services the user explicitly asks about

If the user asks for anything that would mutate state, refuse and explain that this skill is read-only.

## Step 1: Resolve the VM IP (optional, for curl checks)

```bash
ssh -G <ssh-host> | grep "^hostname "
```

Use the resolved IP for any curl commands later in the session.

## Step 2: Discovery Phase

Run when no container names were supplied, or when the user explicitly asks "what's running" / "list containers" / similar.

List running containers with a clean, parseable format:

```bash
ssh <ssh-host> "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
```

To include stopped containers as well, add `-a`:

```bash
ssh <ssh-host> "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'"
```

Present the list to the user and ask which containers they'd like to tail. If there are obvious candidates based on the user's stated goal (e.g. they mentioned a service name that matches a container), suggest those by name.

## Step 3: Tail Logs

For each container the user selected (or supplied as arguments), start a background log stream. Launch all streams in parallel:

```bash
ssh <ssh-host> "docker logs -f --tail 1000 <container-name>" 2>&1
# Run with run_in_background: true
```

Repeat one invocation per container. Tell the user which streams are running and that you'll check them as needed.

Use `Read` on the background output files to inspect logs during the session. When the user describes a symptom, grep through the captured output rather than re-tailing.

### Useful log scoping

If the user wants only recent activity rather than 1000 lines of history:

```bash
ssh <ssh-host> "docker logs --since 10m <container-name>" 2>&1
```

If the user wants a one-shot snapshot rather than a follow stream, drop `-f` and don't background it.

## Step 4: Connectivity Checks (optional)

If the user wants to verify a service is reachable, use the resolved IP from Step 1 and curl the relevant port. Always write multi-line curl commands to a shell script under `/tmp/` first to avoid SSH quoting issues, then execute the script:

```bash
cat > /tmp/check_<service>.sh <<'EOF'
#!/bin/bash
curl -sS -X GET http://<resolved-ip>:<port>/<path>
EOF
bash /tmp/check_<service>.sh
```

Only hit endpoints the user explicitly asked about. Do not probe arbitrary ports.

## Notes

- Container names with special characters should be quoted on the remote side: `ssh <host> "docker logs -f 'my-weird.name'"`.
- If `docker ps` requires sudo on the target VM, prefix the remote command with `sudo` only after confirming with the user; some hosts add the SSH user to the `docker` group and don't need it.
- If the user references a container that isn't in `docker ps` output, re-run discovery with `-a` to check whether it exited, and surface the exit status from the `Status` column.
