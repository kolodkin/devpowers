---
name: check-pr
description: >
  After a git push, find the PR for the current branch, watch CI checks
  through to completion via the GitHub MCP server, and surface
  unresolved review comments. On failure, report the failed checks with
  their run URLs so they can be triaged. Use after every git push, or
  when the user asks to check PR / CI / review status (e.g.
  "/check-pr", "/check-pr --comments-only", "check the PR", "is CI
  green?"). Auto-invokes /setup-mcp github if the GitHub MCP server
  isn't registered.
---

# PR Check Skill

You are a PROACTIVE GitHub PR assistant. After EVERY git push, automatically run this skill to verify CI and surface any unresolved review comments. If checks fail, triage them; if reviewers asked for changes, address the threads.

## Invocation

```
/check-pr                  # full flow: PR lookup → CI watch → review comments
/check-pr --comments-only  # skip CI watch, only surface unresolved review threads
```

## Step 0 — Ensure GitHub MCP is available

This skill drives everything through the `mcp__github__*` tools. Confirm the server is registered before doing anything else.

- **If `mcp__github__list_pull_requests` is visible in your tool list**, proceed.
- **If it's missing**, tell the user one line — "GitHub MCP isn't registered; running `/setup-mcp github` first." — then invoke the `setup-mcp` skill via the Skill tool with argument `github`. After it completes, the user will need to restart Claude Code; stop the current run and ask them to re-invoke `/check-pr` once the new server is loaded.

## Step 1 — Resolve repo and branch

Two cheap shell commands:

```bash
git remote get-url origin
git rev-parse --abbrev-ref HEAD
```

Parse `owner/repo` from the remote URL. Accept `github.com[:/]<owner>/<repo>(.git)` and proxied `/git/<owner>/<repo>` forms. If parsing fails, surface the remote URL to the user and stop — don't guess.

## Step 2 — Find the PR for this branch

Call `mcp__github__list_pull_requests` with `owner`, `repo`, `state: "open"`, and `head: "<owner>:<branch>"`. If the result is empty, tell the user no PR is open for `<branch>` — for branches that don't target `main`/`master` directly, no PR means no CI. Offer to create one with `mcp__github__create_pull_request` only if the user explicitly asks; otherwise stop.

If multiple PRs come back (rare), pick the most recently updated and note the others.

Cache the PR number (`<pr>`) for the rest of the run.

## Step 3 — Check review comments

Call `mcp__github__pull_request_read` with `method: "get_review_comments"`, `owner`, `repo`, `pullNumber: <pr>`. The response contains review threads with `isResolved`, `isOutdated`, `isCollapsed` flags and the comments inside each.

Filter to threads where `isResolved == false && isOutdated == false`. For each:

- Show file path, line number, the last comment's body (most recent concern), and the **root comment ID** (the first comment's `databaseId` / `id` in the thread — this is what `add_reply_to_pull_request_comment` needs).

If there are unresolved threads, render a compact summary block:

```
📝 N UNRESOLVED REVIEW THREAD(S)
  ID: <root-id>  File: <path>:<line>
  Comment: <last comment body>
  ---
  ...
```

Also call `mcp__github__pull_request_read` with `method: "get"` to read `reviewDecision` (`APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or null) and surface it.

If invoked with `--comments-only`, stop here. Otherwise continue to Step 4.

## Step 4 — Check CI status

Call `mcp__github__pull_request_read` with `method: "get_check_runs"`, `owner`, `repo`, `pullNumber: <pr>`. Each check run has `name`, `status` (`queued` / `in_progress` / `completed`), `conclusion` (`success` / `failure` / `cancelled` / `skipped` / `neutral` / `timed_out`), and `html_url`.

Classify the runs into three buckets:

- **Pending** — `status != "completed"`
- **Failed** — `status == "completed" && conclusion in {"failure", "cancelled", "timed_out"}`
- **Passed** — everything else

### 4a. All passed

Print a single SUCCESS block with the PR number, the list of passed checks, and re-run Step 3 (review comments) in case anything came in while CI was running.

### 4b. Any failed

Print a FAILURE block listing each failed check by name with its `html_url`. Then, for each failed check that is GitHub-Actions-backed (the check run's `external_id` is set and the workflow lives in this repo), fetch the job log directly from the GitHub REST API:

```bash
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/jobs/$JOB_ID/logs"
```

`$JOB_ID` is the failed check run's `external_id`. The response is plain text — timestamped lines, `##[group]` markers, command output — identical in shape to `gh run view --log-failed`. `$GH_TOKEN` is the same Personal Access Token that the GitHub MCP server is authenticated with; see `/setup-mcp github` and `skills/setup-mcp/mcps.json` for how it's configured.

If `$GH_TOKEN` isn't set, surface that and tell the user to follow the `/setup-mcp github` flow (which documents the PAT requirement) — do NOT fall back to `gh` CLI install.

If a failed check isn't Actions-backed (third-party CI: CodeQL, external integrations), `external_id` won't map to a job ID. For those, the `html_url` is the only signal — ask the user to open it and paste relevant lines.

When you have logs, present a tight summary (failed step name + last ~30 lines of error output) rather than dumping the full log. The full log is large — quote selectively.

Do NOT loop polling on a CI failure — stop and let the user direct.

### 4c. Any pending

Arm a `Monitor` that polls the check-runs REST endpoint and emits only on state transitions. Stdout lines wake the session — no `sleep`, no polling in the main turn.

First, fetch the head SHA: call `mcp__github__pull_request_read` with `method: "get"`, `pullNumber: <pr>` and read `head.sha`. Confirm `$GH_TOKEN` is set (same token used in 4b); if not, surface that and follow the `/setup-mcp github` flow.

Then arm a persistent `Monitor` (substitute `<owner>`, `<repo>`, `<sha>`):

```bash
prev=""
while true; do
  s=$(curl -fsSL \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/<owner>/<repo>/commits/<sha>/check-runs?per_page=100" || true)
  cur=$(jq -r '.check_runs[] | select(.status=="completed") | "\(.name): \(.conclusion)"' <<<"$s" | sort)
  comm -13 <(echo "$prev") <(echo "$cur")
  prev=$cur
  jq -e '.check_runs | all(.status=="completed")' <<<"$s" >/dev/null && break
  sleep 30
done
```

Print a one-line "watching #<pr> via Monitor — will report when CI completes" status and **end your turn**.

When a notification arrives, re-run Step 4 (a single `get_check_runs` MCP call) for full classification and act per 4a or 4b. The Monitor exits on its own when all checks are terminal; no explicit stop needed. If the user cancels mid-watch, use `TaskStop` with the Monitor's task ID.

## Step 5 — Address PR review comments

If Step 3 surfaced unresolved threads, address them ONLY (skip resolved/outdated ones).

**Fix flow:**
1. Make the requested change, commit, push.
2. Reply in the comment thread to record what was fixed:
   ```
   mcp__github__add_reply_to_pull_request_comment(
     owner, repo, pullNumber: <pr>,
     commentId: <root-id>,
     body: "[Agent] Fixed - <one line: what was fixed>"
   )
   ```

**Clarification flow** (when the comment is ambiguous):
- Reply with `[Agent] Question: <your question>` using the same tool — don't guess.

**Conventions:**
- Always prefix the agent's reply body with `[Agent]` so it's distinguishable from human replies.
- Reply via `add_reply_to_pull_request_comment` (keeps the thread together) — do not open a new top-level review.
- Only act on `isResolved == false && isOutdated == false` threads.
- Keep replies one-line concise.

After pushing fixes, re-run `/check-pr` to verify the new CI run and pick up any new comments.

## Notes

- The GitHub MCP server doesn't expose workflow log bodies as a tool, so Step 4b uses a direct REST API call (`/actions/jobs/{job_id}/logs`) with the same `GH_TOKEN` the MCP server uses. This is the one CLI-shaped escape hatch in the skill; if a future `mcp__github__*` tool returns job logs, replace the curl with it.
- The `Monitor` is session-bound. If the session ends before CI completes, the monitor dies; the next `/check-pr` will pick up wherever things are.
- This skill never pushes commits on its own. Fixes come from other skills (`git-commit`, manual edits + push). `/check-pr` only observes and reports.
