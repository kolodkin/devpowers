# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

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
- **jira-setup** — Ensure the `mcp-atlassian` MCP server is registered (via `setup-mcp`) and resolve Jira defaults (URL, auth, project, board) so `jira-ticket` can run. Idempotent — re-runs only prompt for missing pieces.
  - MCP: `mcp-atlassian` (registered on demand via `setup-mcp`; not bundled)
  - CLI: `uvx` (launches the `mcp-atlassian` server)
  - Env: `JIRA_URL`, plus `JIRA_USERNAME` + `JIRA_API_TOKEN` (Cloud) **or** `JIRA_PERSONAL_TOKEN` (Server / Data Center). Optional: `JIRA_PROJECT_KEY`, `JIRA_BOARD_ID` (offered for shell-rc persistence).
  - Token: Atlassian API token (Cloud) or Personal Access Token (Server / DC)
- **jira-ticket** — Create or comment on Jira tickets in your configured project with structured descriptions; supports create / comment / update-description modes, sprint placement, epic linking, and labels. Auto-invokes `jira-setup` if anything's missing.
  - MCP: `mcp-atlassian` (registered on demand via `setup-mcp`; not bundled)
  - Env: same as `jira-setup`
- **shortify** — Review and shorten markdown docs in subdirectories, plus code comments and docstrings (manual/session opt-in) — cut wordiness, redundancy, and code duplication.
- **screenshots** — Run the project's existing Playwright tests, collect the screenshots they write (inline `page.screenshot()` calls by default; `screenshot: 'on'` per test with `--screenshot-on`), and post-process them into a single self-contained `index.html` (base64-embedded). PR-ready visual record; no parallel capture script to maintain.
  - CLI: `npx`/`node` or `pytest`/`uv`, plus `playwright` browsers (`playwright install chromium`)
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
  - CLI: `git`
- **setup-mcp** — Register a known MCP server (from the curated `mcps.json` manifest) into `./.mcp.json` or the user's Claude Code config. Bounded to vetted entries; refuses unknown names. Use to install `github`, `mcp-atlassian`, or any future entry added to the manifest.
  - CLI: `claude` (for `claude mcp add`), plus whatever the chosen MCP entry requires (`docker`, `uvx`, ...)
- **ssh-docker-debug** — Discover and tail logs for Docker containers running on a remote VM over SSH (read-only).
  - CLI: `ssh`, `docker` (on the remote host), `curl`
- **local-docker-debug** — Discover and tail logs for Docker containers running on the local Docker daemon (read-only).
  - CLI: `docker`, `curl`
