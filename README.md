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
- **shortify** — Review and shorten markdown docs in subdirectories — cut wordiness, redundancy, and code duplication.
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
  - CLI: `git`
- **local-skill** — Download a single skill directory from a GitHub repository into the current project's `.claude/skills/` (public repos only).
  - CLI: `curl`, `tar`
- **setup-mcp** — Register a known MCP server (from the curated `mcps.json` manifest) into `./.mcp.json` or the user's Claude Code config. Bounded to vetted entries; refuses unknown names. Use to install `github`, `mcp-atlassian`, or any future entry added to the manifest.
  - CLI: `claude` (for `claude mcp add`), plus whatever the chosen MCP entry requires (`docker`, `uvx`, ...)
- **ssh-docker-debug** — Discover and tail logs for Docker containers running on a remote VM over SSH (read-only).
  - CLI: `ssh`, `docker` (on the remote host), `curl`
- **local-docker-debug** — Discover and tail logs for Docker containers running on the local Docker daemon (read-only).
  - CLI: `docker`, `curl`


## Bootstrap `local-skill`

For environments without plugin support (e.g. claude.ai/code), install just the `local-skill` skill into the current project's `.claude/skills/`:

```
curl -fsSL https://raw.githubusercontent.com/kolodkin/devpowers/HEAD/local_skill_install.sh | bash
```

Once installed, use `local-skill` to pull additional skills into the project on demand.
