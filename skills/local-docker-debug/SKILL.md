---
name: local-docker-debug
description: Debug Docker containers running locally. Use when the user wants to discover running containers, tail local docker logs, or troubleshoot services running on this machine. Triggers on mentions of "local docker logs", "tail container logs", "what's running locally", "docker debug", or debugging containers on the local Docker daemon.
---

# Local Docker Debugging

Discover and tail logs for Docker containers running on the local Docker daemon.

## Arguments

```
/local-docker-debug [container-name ...]
```

- **container-name** (optional, repeatable) — One or more container names or IDs to tail. If omitted, run the discovery phase and ask the user which containers to tail.

## IMPORTANT

This skill is strictly read-only on the local Docker daemon. NEVER run `docker exec`, `docker build`, `docker compose up/down`, `docker run`, `docker rm`, `docker stop`, `docker restart`, or any command that modifies container or host state. Only the following are allowed:

- `docker ps` (and variants with `--format`, `-a`, `--filter`)
- `docker logs` (with `--tail`, `--since`, `-f`)
- `docker inspect` (read-only metadata)
- `curl` for connectivity checks against services the user explicitly asks about

If the user asks for anything that would mutate state, refuse and explain that this skill is read-only.

## Step 1: Discovery Phase

Run when no container names were supplied, or when the user explicitly asks "what's running" / "list containers" / similar.

List running containers with a clean, parseable format:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

To include stopped containers as well, add `-a`:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Present the list to the user and ask which containers they'd like to tail. If there are obvious candidates based on the user's stated goal (e.g. they mentioned a service name that matches a container), suggest those by name.

## Step 2: Tail Logs

For each container the user selected (or supplied as arguments), start a background log stream. Launch all streams in parallel:

```bash
docker logs -f --tail 1000 <container-name> 2>&1
# Run with run_in_background: true
```

Repeat one invocation per container. Tell the user which streams are running and that you'll check them as needed.

Use `Read` on the background output files to inspect logs during the session. When the user describes a symptom, grep through the captured output rather than re-tailing.

### Useful log scoping

If the user wants only recent activity rather than 1000 lines of history:

```bash
docker logs --since 10m <container-name> 2>&1
```

If the user wants a one-shot snapshot rather than a follow stream, drop `-f` and don't background it.

## Step 3: Connectivity Checks (optional)

If the user wants to verify a service is reachable, curl the relevant port on `localhost` (or the published host port). For multi-line or complex curl commands, write to a shell script under `/tmp/` first to avoid quoting issues, then execute the script:

```bash
cat > /tmp/check_<service>.sh <<'EOF'
#!/bin/bash
curl -sS -X GET http://localhost:<port>/<path>
EOF
bash /tmp/check_<service>.sh
```

To find the host port a container publishes, check the `Ports` column from `docker ps`, or:

```bash
docker inspect --format '{{json .NetworkSettings.Ports}}' <container-name>
```

Only hit endpoints the user explicitly asked about. Do not probe arbitrary ports.

## Notes

- Container names with special characters can be passed directly without extra quoting since there's no SSH layer: `docker logs -f my-weird.name`.
- If `docker ps` fails with a permission error, the current user likely isn't in the `docker` group. Suggest using `sudo` only after confirming with the user; do not silently escalate.
- If the user references a container that isn't in `docker ps` output, re-run discovery with `-a` to check whether it exited, and surface the exit status from the `Status` column.
- For containers running under Docker Compose, the container name is typically `<project>-<service>-<index>` (e.g. `myapp-web-1`). Use that exact name with `docker logs`, not the service name from `docker-compose.yml`.
