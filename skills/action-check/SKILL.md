---
name: action-check
description: Check the latest GitHub Actions workflow run result through the GitHub MCP server's token (no gh CLI). Use when the user asks to check, inspect, or view the status of a workflow run (e.g. "/action-check pypi publish", "/action-check test"). Auto-invokes /setup-mcp github if GitHub auth isn't configured.
---

# Action Check Skill

Check the latest run of a GitHub Actions workflow, monitor it if still in progress, report the result, and fix failures automatically — driven by the GitHub REST API authenticated with the same `$GH_TOKEN` the GitHub MCP server uses. No `gh` CLI install, no separate OAuth.

## Invocation Format

```
/action-check <workflow description>
```

Examples:
```
/action-check hello
/action-check pypi publish
/action-check generate migration
```

## Step 0 — Ensure GitHub auth is available

This skill talks to GitHub with the same Personal Access Token the GitHub MCP server authenticates with (`$GH_TOKEN`). GitHub's hosted MCP server doesn't expose an Actions toolset — there's no `mcp__github__list_workflow_runs` tool — so reading run status goes through the GitHub REST API with that token, exactly like `/check-pr`'s log-fetch curl.

- Confirm the token is set: `[ -n "$GH_TOKEN" ] && echo set || echo MISSING`.
- **If missing**, check whether the GitHub MCP is registered (is `mcp__github__list_pull_requests` in your tool list?). If neither the token nor the MCP is present, tell the user one line — "GitHub auth isn't configured; running `/setup-mcp github` first." — then invoke the `setup-mcp` skill via the Skill tool with argument `github`. After it completes, the user must `export GH_TOKEN=<pat>` and re-run `/action-check`; stop the current run.

Reading runs only needs **Actions: read** (classic `repo` scope, or fine-grained `Actions: read`). See `/setup-mcp github` and `skills/setup-mcp/mcps.json` for how the token is configured.

## Step 1 — Resolve repo

```bash
git remote get-url origin
```

Parse `owner/repo` from the remote URL. Accept `github.com[:/]<owner>/<repo>(.git)` and proxied `/git/<owner>/<repo>` forms. If parsing fails, surface the remote URL and stop — don't guess.

## Step 2 — Identify the workflow file

List available workflows:
```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify. The REST API accepts the workflow file name (e.g. `hello.yaml`) as the workflow id.

## Step 3 — Find the latest run

```bash
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>/actions/workflows/<workflow>/runs?per_page=1" \
  | jq -r '.workflow_runs[0] | "\(.id)\t\(.status)\t\(.conclusion // "running")\t\(.head_branch)\t\(.display_title)\t\(.html_url)"'
```

If `.workflow_runs` is empty, tell the user no runs exist for `<workflow>` and stop. Otherwise cache the run `id`, `status`, and `conclusion`, and surface the run number, branch, title, and URL.

## Step 4 — Monitor if in progress

If `status != "completed"`, arm a `Monitor` that polls the run and emits only on status transitions — stdout lines wake the session, no `sleep` in the main turn (substitute `<owner>`, `<repo>`, `<run_id>`):

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

The emitted line carries both `status` and `conclusion`, so it covers the success **and** failure terminal states. Print a one-line "watching run #<run_id> via Monitor — will report when it completes" status and **end your turn**. When the notification arrives, re-fetch the run (`/actions/runs/<run_id>`) for the final `conclusion` and act per Step 5. If the user cancels mid-watch, use `TaskStop` with the Monitor's task ID.

If `status == "completed"` already, go straight to Step 5.

## Step 5 — Report result and handle failures

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
3. Use `/action-run` to trigger a new run.

Only ask the user for input when the fix genuinely requires a decision. Otherwise fix and retry autonomously. Do NOT loop polling on a failure — stop after reporting and let the user direct.

## Notes

- GitHub's hosted MCP server doesn't expose the Actions toolset, so this skill uses the REST API with the same `$GH_TOKEN` the MCP server authenticates with — the one CLI-shaped escape hatch, identical in spirit to `/check-pr`'s log fetch. If a future `mcp__github__*` Actions tool appears (`list_workflow_runs`, `get_workflow_run`, `get_job_logs`), replace the corresponding curl with it.
- This skill only observes and reports — it never triggers runs. Use `/action-run` to start one.
