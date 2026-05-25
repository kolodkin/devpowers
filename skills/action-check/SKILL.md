---
name: action-check
description: Check the latest GitHub Actions workflow run result through the GitHub MCP server's actions toolset (no gh CLI). Use when the user asks to check, inspect, or view the status of a workflow run (e.g. "/action-check pypi publish", "/action-check test"). Auto-invokes /setup-mcp github if the actions toolset isn't registered.
---

# Action Check Skill

Check the latest run of a GitHub Actions workflow, monitor it if still in progress, report the result, and fix failures automatically — driven through the GitHub MCP server's **actions** toolset (`mcp__github__actions_*`, `mcp__github__get_job_logs`), exactly the way `/check-pr` drives PR/CI status through `mcp__github__pull_request_read`. No `gh` CLI.

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

## Step 0 — Ensure the GitHub MCP actions toolset is available

This skill drives everything through the GitHub MCP server's **actions** toolset. GitHub's hosted server doesn't enable that toolset by default, so confirm the actions tools are registered before doing anything else.

- **If `mcp__github__get_job_logs` (and the `mcp__github__actions_*` tools) are visible in your tool list**, proceed.
- **If they're missing**, tell the user one line — "GitHub MCP actions toolset isn't registered; running `/setup-mcp github` first." — then invoke the `setup-mcp` skill via the Skill tool with argument `github project` so it writes/updates the `github` server into the project's `./.mcp.json` (its `mcps.json` entry includes the `X-MCP-Toolsets: all` header that enables the actions toolset). After it completes, the user must restart Claude Code; stop the current run and ask them to re-invoke `/action-check` once the new server loads.
- **If `/setup-mcp` reports the `github` server is already registered but the actions tools still aren't in your tool list**, the existing registration predates the actions toolset — ask `/setup-mcp` to reconfigure (force) so the `X-MCP-Toolsets` header is applied, then restart.

Reading runs only needs **Actions: read** (classic `repo` scope / fine-grained `Actions: read`).

**Tool shape:** the hosted server groups Actions operations into method-based tools — `mcp__github__actions_list` (methods `list_workflows`, `list_workflow_runs`, `list_workflow_jobs`), `mcp__github__actions_get` (`get_workflow_run`), and the standalone `mcp__github__get_job_logs`. Server versions may rename these or shift methods; map the intent below to whatever `mcp__github__*` actions tools your session actually exposes, and read each tool's registered schema for exact filter/pagination parameters.

## Step 1 — Resolve repo

```bash
git remote get-url origin
```

Parse `owner/repo` from the remote URL. Accept `github.com[:/]<owner>/<repo>(.git)` and proxied `/git/<owner>/<repo>` forms. If parsing fails, surface the remote URL and stop — don't guess.

## Step 2 — Identify the workflow file

```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify. The actions tools accept the workflow file name (e.g. `hello.yaml`) as the workflow id.

## Step 3 — Find the latest run

Call `mcp__github__actions_list` with method `list_workflow_runs`, `owner`, `repo`, `resource_id: "<workflow>"` (the file name), newest first (per-page 1 via the tool's pagination params). If no runs come back, tell the user no runs exist for `<workflow>` and stop.

Otherwise cache the run `id`, `status`, and `conclusion`, and surface the run number, head branch, title, and URL.

## Step 4 — Monitor if in progress

If `status != "completed"`, arm a `Monitor` that emits on status transitions and **end your turn**. A `Monitor` runs a shell command and can't invoke MCP tools mid-loop, so it polls the REST run endpoint with the same `$GH_TOKEN` the MCP server authenticates with — the one shell touchpoint, identical to `/check-pr`'s CI watch. Confirm `$GH_TOKEN` is set first; if not, surface that (it's the same token the MCP uses).

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

The emitted line carries `status` and `conclusion`, covering the success **and** failure terminal states. Print a one-line "watching run #<run_id> via Monitor — will report when it completes" status and end your turn. When the notification arrives, re-call `mcp__github__actions_get` (`get_workflow_run`, `resource_id: "<run_id>"`) for the final `conclusion` and act per Step 5. If the user cancels mid-watch, use `TaskStop` with the Monitor's task ID.

If `status == "completed"` already, go straight to Step 5.

## Step 5 — Report result and handle failures

**On `conclusion == "success"`** — report the run URL (`https://github.com/<owner>/<repo>/actions/runs/<run_id>`) and stop.

**On failure** (`failure` / `cancelled` / `timed_out`) — fetch the failed job logs through MCP. Call `mcp__github__get_job_logs` with:
- `owner`, `repo`
- `run_id: <run_id>`
- `failed_only: true`
- `return_content: true`
- `tail_lines: 50` (adjust as needed)

This returns the tail of every failed job's log directly — no curl. Present a tight summary (failed step name + the key error lines), not the full dump.

Then:
1. Fix the root cause (failing tests, bad inputs, version conflicts).
2. Commit and push fixes if needed.
3. Use `/action-run` to trigger a new run.

Only ask the user for input when the fix genuinely requires a decision. Otherwise fix and retry autonomously. Do NOT loop polling on a failure — stop after reporting and let the user direct.

## Notes

- Every GitHub Actions read — run lookup, status, logs — goes through the MCP actions toolset (`actions_list` / `actions_get` / `get_job_logs`). The only shell touchpoint is the Step 4 `Monitor`, which polls REST with the shared `$GH_TOKEN` because a `Monitor` can't call MCP tools mid-loop — the same arrangement `/check-pr` uses for its CI watch.
- This skill only observes and reports — it never triggers runs. Use `/action-run` to start one.
