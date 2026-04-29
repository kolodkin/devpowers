# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

## Skills

- **action-run** — Trigger and monitor any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, and fix failures automatically.
  - CLI: `gh`, `git`
  - Env: `GH_TOKEN`
  - Token: repo write/admin — classic PAT `workflow`, fine-grained `Actions: write`
- **action-check** — Check the latest GitHub Actions workflow run, monitor in-progress runs, and report failures with logs.
  - CLI: `gh`, `git`
  - Env: `GH_TOKEN`
  - Token: repo read — classic PAT `repo` (private repos), fine-grained `Actions: read`
- **check-pr** — After a push, poll PR check status until complete, surface unresolved review comments, and report failure logs.
  - CLI: `gh`, `git`
  - Env: `GH_TOKEN`
  - Token: classic PAT `repo`, fine-grained `Pull requests: read/write`, `Actions: read`
- **jira-setup** — Configure the `mcp-atlassian` MCP server and Jira defaults (URL, auth, project, board) so `jira-ticket` can run. Idempotent — re-runs only prompt for missing pieces.
  - MCP: `mcp-atlassian` (registered into `./.mcp.json`)
  - CLI: `uvx` (to launch the MCP server)
  - Env: `JIRA_URL`, plus `JIRA_USERNAME` + `JIRA_API_TOKEN` (Cloud) **or** `JIRA_PERSONAL_TOKEN` (Server / Data Center). Optional: `JIRA_PROJECT_KEY`, `JIRA_BOARD_ID` (offered for shell-rc persistence).
  - Token: Atlassian API token (Cloud) or Personal Access Token (Server / DC)
- **jira-ticket** — Create or comment on Jira tickets in your configured project with structured descriptions; supports create / comment / update-description modes, sprint placement, epic linking, and labels. Auto-invokes `jira-setup` if env vars are missing.
  - MCP: `mcp-atlassian`
  - Env: same as `jira-setup`
- **shortify** — Review and shorten markdown docs in subdirectories — cut wordiness, redundancy, and code duplication.
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
  - CLI: `git`
- **local-skill** — Download a single skill directory from a GitHub repository into the current project's `.claude/skills/` (public repos only).
  - CLI: `curl`, `tar`


## Bootstrap `local-skill`

For environments without plugin support (e.g. claude.ai/code), install just the `local-skill` skill into the current project's `.claude/skills/`:

```
curl -fsSL https://raw.githubusercontent.com/kolodkin/devpowers/HEAD/local_skill_install.sh | bash
```

Once installed, use `local-skill` to pull additional skills into the project on demand.
