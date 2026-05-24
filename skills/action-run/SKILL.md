---
name: action-run
description: Trigger and monitor any GitHub Actions workflow through the GitHub MCP server's token (no gh CLI). Use when the user asks to run, trigger, or execute a GitHub Action (e.g. "/action-run pypi publish", "/action-run generate migration"). Auto-invokes /setup-mcp github if GitHub auth isn't configured.
---

# Action Run Skill

Trigger any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, monitor it to completion, and fix failures automatically — driven by the GitHub REST API authenticated with the same `$GH_TOKEN` the GitHub MCP server uses. No `gh` CLI install, no separate OAuth.

## Invocation Format

```
/action-run <workflow description> [key=value] [flag] ... [branch=<name>]
```

Examples:
```
/action-run hello
/action-run hello name=Mark shout
/action-run pypi publish tag=v0.0.8 pre-release
/action-run pypi publish tag=v0.0.8 branch=main
/action-run generate migration message="add users table"
```

## Step 0 — Ensure GitHub auth is available

This skill talks to GitHub with the same Personal Access Token the GitHub MCP server authenticates with (`$GH_TOKEN`). GitHub's hosted MCP server doesn't expose an Actions toolset — there's no `mcp__github__run_workflow` tool — so triggering and monitoring go through the GitHub REST API with that token, exactly like `/check-pr`'s log-fetch curl.

- Confirm the token is set: `[ -n "$GH_TOKEN" ] && echo set || echo MISSING`.
- **If missing**, check whether the GitHub MCP is registered (is `mcp__github__list_pull_requests` in your tool list?). If neither the token nor the MCP is present, tell the user one line — "GitHub auth isn't configured; running `/setup-mcp github` first." — then invoke the `setup-mcp` skill via the Skill tool with argument `github`. After it completes, the user must `export GH_TOKEN=<pat>` and re-run `/action-run`; stop the current run.

Triggering `workflow_dispatch` needs a token with **Actions: write** — classic PATs need the `workflow` scope, fine-grained PATs need `Actions: write`. See `/setup-mcp github` and `skills/setup-mcp/mcps.json` for how the token is configured.

## Step 1 — Resolve repo and branch

Two cheap shell commands:

```bash
git remote get-url origin
git rev-parse --abbrev-ref HEAD
```

Parse `owner/repo` from the remote URL. Accept `github.com[:/]<owner>/<repo>(.git)` and proxied `/git/<owner>/<repo>` forms. If parsing fails, surface the remote URL and stop — don't guess.

The default ref is the current branch. A `branch=<name>` argument overrides it — it controls which branch the workflow runs on, it is **not** a workflow input.

## Step 2 — Identify the workflow file

List available workflows:
```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify. The REST API accepts the workflow file name (e.g. `hello.yaml`) as the workflow id.

## Step 3 — Discover required inputs

Read the matched workflow file (Read tool, or `cat .github/workflows/<file>`). Find the `on.workflow_dispatch.inputs` section. For each input:
- **required: true** — must be provided before running
- **required: false** / no `required` field — optional, has a default

## Step 4 — Gather missing inputs

Check which required inputs were **not** supplied in the invocation. Ask the user for any that are missing.

Inputs already provided in the invocation become entries in the dispatch `inputs` object (all values sent as strings — GitHub coerces booleans/numbers):
- `tag=v0.0.8` → `"tag": "v0.0.8"`
- `pre-release` (bare flag) → `"pre-release": "true"`

## Step 5 — Check for an already-running workflow

Don't re-trigger if one is already in flight — monitor it instead:

```bash
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/workflows/<workflow>/runs?per_page=10" \
  | jq '[.workflow_runs[] | select(.status=="in_progress" or .status=="queued" or .status=="waiting")]'
```

If the array is non-empty, take the newest active run's `.id` and skip to Step 7 (monitor it). Otherwise continue.

## Step 6 — Trigger the workflow

```bash
curl -fsS -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/workflows/<workflow>/dispatches" \
  -d '{"ref":"<branch>","inputs":{"name":"Mark","shout":"true"}}'
```

Omit `"inputs"` entirely if the workflow takes none. A **204 No Content** (empty response) means success. Handle errors:
- **403 / "Resource not accessible"** — the token can't trigger `workflow_dispatch`. Classic PATs: add the `workflow` scope at github.com/settings/tokens. Fine-grained PATs: enable `Actions: write`.
- **404 / 422** — bad `ref` (branch not pushed?) or an input that doesn't match the workflow's declared inputs. Re-check Step 1 and Step 3.

Then resolve the new run id — it takes a few seconds to register, so retry up to ~5 times:

```bash
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/workflows/<workflow>/runs?branch=<branch>&event=workflow_dispatch&per_page=1" \
  | jq -r '.workflow_runs[0].id'
```

## Step 7 — Monitor the run to completion

If the run is already `completed`, skip to Step 8. Otherwise arm a `Monitor` that polls the run and emits only on status transitions — stdout lines wake the session, no `sleep` in the main turn (substitute `<owner>`, `<repo>`, `<run_id>`):

```bash
prev=""
while true; do
  s=$(curl -fsSL \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/<owner>/<repo>/actions/runs/<run_id>" || true)
  cur=$(jq -r '"\(.status) \(.conclusion // "-")"' <<<"$s")
  [ "$cur" != "$prev" ] && echo "$cur"
  prev=$cur
  jq -e '.status=="completed"' <<<"$s" >/dev/null && break
  sleep 20
done
```

The emitted line carries both `status` and `conclusion`, so it covers the success **and** failure terminal states. Print a one-line "watching run #<run_id> via Monitor — will report when it completes" status and **end your turn**. When the notification arrives, re-fetch the run (`/actions/runs/<run_id>`) for the final `conclusion` and act per Step 8. If the user cancels mid-watch, use `TaskStop` with the Monitor's task ID.

## Step 8 — Report result and handle failures

**On `conclusion == "success"`** — report the run URL (`https://github.com/<owner>/<repo>/actions/runs/<run_id>`) and stop.

**On failure** (`failure` / `cancelled` / `timed_out`) — fetch the failed job logs. First list jobs and pick the failed ones:

```bash
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/runs/<run_id>/jobs" \
  | jq -r '.jobs[] | select(.conclusion=="failure") | "\(.id)\t\(.name)"'
```

Then fetch a failed job's log (plain text, follow the redirect with `-L`):

```bash
curl -fsSL -L \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/jobs/<job_id>/logs"
```

This is the same `/actions/jobs/{job_id}/logs` endpoint `/check-pr` uses. The response is large — present a tight summary (failed step name + last ~30 lines of error output), not the full dump.

Then:
1. Fix the root cause (failing tests, bad inputs, version conflicts).
2. Commit and push fixes if needed.
3. Re-run this skill with the same or corrected inputs.

Only ask the user for input when the fix genuinely requires a decision (e.g. choosing a new version number). Otherwise fix and retry autonomously. Do NOT loop polling on a failure — stop after reporting and let the user direct.

## Notes

- GitHub's hosted MCP server doesn't expose the Actions toolset, so this skill uses the REST API with the same `$GH_TOKEN` the MCP server authenticates with — the one CLI-shaped escape hatch, identical in spirit to `/check-pr`'s log fetch. If a future `mcp__github__*` Actions tool appears (`run_workflow`, `get_workflow_run`, `get_job_logs`), replace the corresponding curl with it.
- The `Monitor` is session-bound. If the session ends before the run completes, the monitor dies; re-run `/action-run` (it detects the active run in Step 5 and resumes monitoring).
