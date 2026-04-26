# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

## Skills

- **action-run** — Trigger and monitor any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, and fix failures automatically. Uses `gh`, `git`; `GH_TOKEN`; needs repo write/admin (classic PAT: `workflow`; fine-grained: `Actions: write`).
- **action-check** — Check the latest GitHub Actions workflow run, monitor in-progress runs, and report failures with logs. Uses `gh`, `git`; `GH_TOKEN`; needs repo read (classic PAT: `repo` for private; fine-grained: `Actions: read`).
- **check-pr** — After a push, poll PR check status until complete, surface unresolved review comments, and report failure logs. Uses `gh`, `git`; `GH_TOKEN`; needs classic PAT: `repo` or fine-grained: `Pull requests: read/write`, `Actions: read`.
- **shortify** — Review and shorten markdown docs in subdirectories — cut wordiness, redundancy, and code duplication. No CLI / env / token.
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically. Uses `git`; no env / token.
- **local-skill** — Download a single skill directory from a GitHub repository into the current project's `.claude/skills/`. Uses `curl`, `tar`; no env / token (public repos only).


## Bootstrap `local-skill`

For environments without plugin support (e.g. claude.ai/code), install just the `local-skill` skill into the current project's `.claude/skills/`:

```
curl -fsSL https://raw.githubusercontent.com/kolodkin/devpowers/HEAD/local_skill_install.sh | bash
```

Once installed, use `local-skill` to pull additional skills into the project on demand.
