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

Print a FAILURE block listing each failed check by name with its `html_url`. **There is no MCP tool to fetch workflow log bodies** — surface the URLs and tell the user (or your next-turn self) to either:

- Open the URL in a browser to read logs
- Paste the relevant failing lines back into the chat so they can be triaged here

If the failures are obviously triageable from the check name alone (e.g. `lint`, `typecheck`, `test`), offer to reproduce locally instead of waiting on log paste.

Do NOT loop polling on a CI failure — stop and let the user direct.

### 4c. Any pending

Subscribe to PR activity so events wake the session instead of blocking on a poll:

- Call `subscribe_pr_activity` with `owner`, `repo`, `pullNumber: <pr>` (and `events` filter if available — at minimum CI + comments + reviews).
- Print a one-line "watching #<pr> — will report when CI completes" status and **end your turn**. Do not `sleep` or poll.
- When a `<github-webhook-activity>` event arrives, re-run Step 4 (a single `get_check_runs` call) to refresh classification, then act per 4a or 4b. If still pending, end the turn again.
- When CI reaches a terminal state and you've reported, call `unsubscribe_pr_activity` to stop receiving further events for this PR.

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

- Workflow log bodies aren't exposed by the GitHub MCP server today. If automated log retrieval becomes critical, add a `mcp__github__*` tool that returns logs to the manifest and update Step 4b — don't reintroduce `gh run view --log-failed` as a shadow path.
- `subscribe_pr_activity` is session-bound. If the session ends before CI completes, the subscription dies; the next `/check-pr` will pick up wherever things are.
- This skill never pushes commits on its own. Fixes come from other skills (`git-commit`, manual edits + push). `/check-pr` only observes and reports.
