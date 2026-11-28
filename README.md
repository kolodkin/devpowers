# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

The GitHub skills need `GH_TOKEN` set.

## Skills

- **action-run** — Trigger and monitor any GitHub Actions `workflow_dispatch` workflow by name through the GitHub MCP server's actions toolset, gather required inputs, and fix failures automatically.
  - MCP: `github` with actions toolset (bundled with this plugin; requires `GH_TOKEN`)
  - CLI: `git`, `curl` (curl only for the in-progress-run Monitor poll)
  - Env: `GH_TOKEN` (long-lived PAT, used by both the MCP server and the Monitor poll)
  - Token: classic PAT `repo` + `workflow`, fine-grained `Actions: write`
- **action-check** — Check the latest GitHub Actions workflow run through the GitHub MCP server's actions toolset, monitor in-progress runs, and report failures with logs.
  - MCP: `github` with actions toolset (bundled with this plugin; requires `GH_TOKEN`)
  - CLI: `git`, `curl` (curl only for the in-progress-run Monitor poll)
  - Env: `GH_TOKEN` (long-lived PAT, used by both the MCP server and the Monitor poll)
  - Token: classic PAT `repo` (private repos), fine-grained `Actions: read`
- **check-pr** — After a push, find the PR for the current branch, watch CI checks through to completion (Monitor poll), surface unresolved review comments, and fetch failed-job logs via the GitHub MCP server's actions toolset (`get_job_logs`).
  - MCP: `github` with actions toolset (bundled with this plugin; requires `GH_TOKEN`)
  - CLI: `git`, `curl` (curl only for the CI-watch Monitor poll)
  - Env: `GH_TOKEN` (long-lived PAT, used by both the MCP server and the Monitor poll)
  - Token: classic PAT `repo`, fine-grained `Pull requests: read/write`, `Actions: read`
- **jira-setup** — Ensure the `mcp-atlassian` MCP server is registered and resolve Jira defaults (URL, auth, project, board) so `jira-ticket` can run. Idempotent — re-runs only prompt for missing pieces.
  - MCP: `mcp-atlassian` (registered on demand by this skill; not bundled)
  - CLI: `claude` (for `claude mcp add`), `uvx` (launches the `mcp-atlassian` server)
  - Env: `JIRA_URL`, plus `JIRA_USERNAME` + `JIRA_API_TOKEN` (Cloud) **or** `JIRA_PERSONAL_TOKEN` (Server / Data Center). Optional: `JIRA_PROJECT_KEY`, `JIRA_BOARD_ID` (offered for shell-rc persistence).
  - Token: Atlassian API token (Cloud) or Personal Access Token (Server / DC)
- **jira-ticket** — Create or comment on Jira tickets in your configured project with structured descriptions; supports create / comment / update-description modes, sprint placement, epic linking, and labels. Auto-invokes `jira-setup` if anything's missing.
  - MCP: `mcp-atlassian` (registered on demand via `jira-setup`; not bundled)
  - Env: same as `jira-setup`
- **shortify** — Review and shorten markdown docs in subdirectories, plus code comments and docstrings (manual/session opt-in) — cut wordiness, redundancy, and code duplication.
- **session-review** — Full review pass over the current branch: runs `code-review`, `simplify`, `ponytail:ponytail-review`, `vmodel` and `shortify` in order, applying fixes between steps.
  - Plugins: `ponytail` (for `ponytail-review`; skipped if absent)
- **vmodel** — The generic V-model method: every behavior has a statement in a doc of record and a test naming its `req:` ID; a change walks down the docs writing a failing test per layer, then up the tests. A project extends it with its own `vmodel` skill naming its layers, paths and commands.
- **ascii-sketch** — Draw a plain-ASCII sketch of a screen, panel, modal or architecture/network diagram for a doc page, design note or chat answer: boxes from `+ - |`, a bullet per control, no box-drawing characters so it renders the same in any font.
- **mermaid-sketch** — Write a Mermaid sequence, flow or state diagram for a doc page, design note or chat answer, render it in headless Chromium to validate the syntax, and show the rendered PNG.
  - CLI: `node`, plus `playwright` with Chromium
- **screenshots** — Run the project's existing Playwright tests, collect the screenshots they write (inline `page.screenshot()` calls by default; `screenshot: 'on'` per test with `--screenshot-on`), and post-process them into a single self-contained `index.html` (base64-embedded). By default scoped to the tests worked on in the current session; `/screenshots all` reports the full suite. PR-ready visual record; no parallel capture script to maintain.
  - CLI: `npx`/`node` or `pytest`/`uv`, plus `playwright` browsers (`playwright install chromium`)
  - CLI: `git`
- **claudeai-setup** — Scaffold a project's `claudeai/` scripts (`_guard.sh`, `run.sh`, one `setup_<svc>.sh` per service) and its project-level `claudeai-run` skill, so a Claude Code web (cloud) session can start the backing services CI gets from Docker. Services come from the project's CI or from the user.
  - CLI: `bash`, `curl`
- **ssh-docker-debug** — Discover and tail logs for Docker containers running on a remote VM over SSH (read-only).
  - CLI: `ssh`, `docker` (on the remote host), `curl`
- **local-docker-debug** — Discover and tail logs for Docker containers running on the local Docker daemon (read-only).
  - CLI: `docker`, `curl`

## Output styles

- **bottom-line** — Terse chat replies: answer first, max 2-3 lines per item, details only on request. Coding behavior is unchanged.
  - Activate: `/output-style devpowers:bottom-line` (or `/config` → Output style). Back: `/output-style default`.
  - Default everywhere: `"outputStyle": "devpowers:bottom-line"` in `~/.claude/settings.json`.
