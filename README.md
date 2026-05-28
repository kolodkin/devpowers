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
- **shortify** — Review and shorten markdown docs in subdirectories — cut wordiness, redundancy, and code duplication.
- **e2e-screenshots-report** — Run the project's existing Playwright tests with `screenshot: 'on'`, then post-process the `test-results/` PNGs into a single self-contained `index.html` (base64-embedded). PR-ready visual record; no parallel capture script to maintain.
  - CLI: `npx`/`node` or `pytest`/`uv`, plus `playwright` browsers (`playwright install chromium`)
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
  - CLI: `git`
- **setup-mcp** — Register a known MCP server (from the curated `mcps.json` manifest) into `./.mcp.json` or the user's Claude Code config. Bounded to vetted entries; refuses unknown names. Use to install `github`, `mcp-atlassian`, or any future entry added to the manifest.
  - CLI: `claude` (for `claude mcp add`), plus whatever the chosen MCP entry requires (`docker`, `uvx`, ...)
- **ssh-docker-debug** — Discover and tail logs for Docker containers running on a remote VM over SSH (read-only).
  - CLI: `ssh`, `docker` (on the remote host), `curl`
- **local-docker-debug** — Discover and tail logs for Docker containers running on the local Docker daemon (read-only).
  - CLI: `docker`, `curl`
