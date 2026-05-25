---
name: action-run
description: Trigger and monitor any GitHub Actions workflow through the GitHub MCP server's actions toolset (no gh CLI). Use when the user asks to run, trigger, or execute a GitHub Action (e.g. "/action-run pypi publish", "/action-run generate migration"). Uses the github MCP server bundled with this plugin (requires GH_TOKEN).
---

# Action Run Skill

Trigger any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, monitor it to completion, and fix failures automatically — driven through the GitHub MCP server's **actions** toolset (`mcp__plugin_devpowers_github__actions_*`, `mcp__plugin_devpowers_github__get_job_logs`), exactly the way `/check-pr` drives PR/CI status through `mcp__plugin_devpowers_github__pull_request_read`. No `gh` CLI.

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

## Step 0 — Ensure the GitHub MCP actions toolset is available

This skill drives everything through the **actions** toolset of the `github` MCP server bundled with this plugin — its `.mcp.json` loads as `mcp__plugin_devpowers_github__*`, and the `X-MCP-Toolsets: all` header turns the actions tools on.

- **If `mcp__plugin_devpowers_github__get_job_logs` (and the `mcp__plugin_devpowers_github__actions_*` tools) are visible in your tool list**, proceed.
- **If they're missing**, the plugin's bundled `github` MCP didn't connect — almost always because `GH_TOKEN` isn't set (it authenticates with `Bearer ${GH_TOKEN}`). Tell the user to `export GH_TOKEN=<pat>` (a long-lived PAT) and restart Claude Code (or run `/reload-plugins`), then re-invoke `/action-run`. Stop until the server loads.

Triggering `workflow_dispatch` needs a token with **Actions: write** (classic `workflow` scope / fine-grained `Actions: write`). A read-only token can list and inspect runs, but `run_workflow` will fail with 403.

**Tool shape:** the hosted server groups Actions operations into method-based tools — `mcp__plugin_devpowers_github__actions_run_trigger` (methods `run_workflow`, `rerun_failed_jobs`, `rerun_workflow_run`, `cancel_workflow_run`), `mcp__plugin_devpowers_github__actions_list` (`list_workflows`, `list_workflow_runs`, `list_workflow_jobs`), `mcp__plugin_devpowers_github__actions_get` (`get_workflow_run`), and the standalone `mcp__plugin_devpowers_github__get_job_logs`. Server versions may rename these or shift methods; map the intent below to whatever `mcp__plugin_devpowers_github__*` actions tools your session actually exposes, and read each tool's registered schema for exact filter/pagination parameters.

## Step 1 — Resolve repo and branch

```bash
git remote get-url origin
git rev-parse --abbrev-ref HEAD
```

Parse `owner/repo` from the remote URL. Accept `github.com[:/]<owner>/<repo>(.git)` and proxied `/git/<owner>/<repo>` forms. If parsing fails, surface the remote URL and stop — don't guess.

The default ref is the current branch. A `branch=<name>` argument overrides it — it controls which branch the workflow runs on, it is **not** a workflow input.

## Step 2 — Identify the workflow file

```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify. The actions tools accept the workflow file name (e.g. `hello.yaml`) as `workflow_id`.

## Step 3 — Discover required inputs

Read the matched workflow file (Read tool). Find the `on.workflow_dispatch.inputs` section. For each input:
- **required: true** — must be provided before running
- **required: false** / no `required` field — optional, has a default

## Step 4 — Gather missing inputs

Check which required inputs were **not** supplied in the invocation. Ask the user for any that are missing.

Inputs already provided become entries in the `inputs` object (send values as strings — GitHub coerces booleans/numbers):
- `tag=v0.0.8` → `"tag": "v0.0.8"`
- `pre-release` (bare flag) → `"pre-release": "true"`

## Step 5 — Check for an already-running workflow

Don't re-trigger if one is already in flight. Call `mcp__plugin_devpowers_github__actions_list` with method `list_workflow_runs`, `owner`, `repo`, and `resource_id: "<workflow>"` (the file name); use the tool's run filter to narrow to active runs (`status` in `queued` / `in_progress` / `waiting`). If any active run comes back, take the newest one's id and skip to **Step 7** (monitor it) instead of triggering. Otherwise continue.

## Step 6 — Trigger the workflow

Call `mcp__plugin_devpowers_github__actions_run_trigger` with method `run_workflow`:
- `owner`, `repo`
- `workflow_id: "<workflow>"` (file name)
- `ref: "<branch>"`
- `inputs: { ... }` (omit when the workflow takes none)

Errors:
- **403 / "Resource not accessible"** — the token lacks `Actions: write` (see Step 0).
- **404 / 422** — bad `ref` (branch not pushed?) or an input that doesn't match the workflow's declared inputs. Re-check Steps 1 and 3.

Then resolve the new run id — it takes a few seconds to register, so retry a couple of times: call `mcp__plugin_devpowers_github__actions_list` method `list_workflow_runs` (`owner`, `repo`, `resource_id: "<workflow>"`) filtered to `branch=<branch>` and `event=workflow_dispatch`, newest first, and read the top run's `id`.

## Step 7 — Monitor the run to completion

Snapshot the run: call `mcp__plugin_devpowers_github__actions_get` method `get_workflow_run` (`owner`, `repo`, `resource_id: "<run_id>"`). If `status == "completed"`, skip to Step 8.

If it's still running, arm a `Monitor` that emits on status transitions and **end your turn**. A `Monitor` runs a shell command and can't invoke MCP tools mid-loop, so it polls the REST run endpoint with the same `$GH_TOKEN` the MCP server authenticates with — the one shell touchpoint, identical to `/check-pr`'s CI watch. Confirm `$GH_TOKEN` is set first; if not, surface that (it's the same token the MCP uses).

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

The emitted line carries `status` and `conclusion`, covering the success **and** failure terminal states. Print a one-line "watching run #<run_id> via Monitor — will report when it completes" status and end your turn. When the notification arrives, re-call `mcp__plugin_devpowers_github__actions_get` (`get_workflow_run`) for the final `conclusion` and act per Step 8. If the user cancels mid-watch, use `TaskStop` with the Monitor's task ID.

## Step 8 — Report result and handle failures

**On `conclusion == "success"`** — report the run URL (`https://github.com/<owner>/<repo>/actions/runs/<run_id>`) and stop.

**On failure** (`failure` / `cancelled` / `timed_out`) — fetch the failed job logs through MCP. Call `mcp__plugin_devpowers_github__get_job_logs` with:
- `owner`, `repo`
- `run_id: <run_id>`
- `failed_only: true`
- `return_content: true`
- `tail_lines: 50` (adjust as needed)

This returns the tail of every failed job's log directly — no curl. Present a tight summary (failed step name + the key error lines), not the full dump.

Then:
1. Fix the root cause (failing tests, bad inputs, version conflicts).
2. Commit and push fixes if needed.
3. Re-run this skill with the same or corrected inputs.

Only ask the user for input when the fix genuinely requires a decision (e.g. choosing a new version number). Otherwise fix and retry autonomously. Do NOT loop polling on a failure — stop after reporting and let the user direct.

## Notes

- Every GitHub Actions operation — trigger, run lookup, status, logs — goes through the MCP actions toolset (`actions_run_trigger` / `actions_list` / `actions_get` / `get_job_logs`). The only shell touchpoint is the Step 7 `Monitor`, which polls REST with the shared `$GH_TOKEN` because a `Monitor` can't call MCP tools mid-loop — the same arrangement `/check-pr` uses for its CI watch.
- The `Monitor` is session-bound. If the session ends before the run completes, re-run `/action-run` — Step 5 detects the active run and resumes monitoring.
