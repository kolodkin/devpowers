# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

### Bootstrap `local-skill` standalone

If you want just the `local-skill` skill (no plugin), drop it into the current project's `.claude/skills/` with:

```
curl -fsSL https://raw.githubusercontent.com/kolodkin/devpowers/HEAD/local_skill_install.sh | bash
```

Pin a different branch/tag/commit by setting `LOCAL_SKILL_REF`. Extra args (e.g. `--force`, `--dry-run`) are forwarded to the installer.

## Skills

- **action-run** — Trigger and monitor any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, and fix failures automatically.
- **action-check** — Check the latest GitHub Actions workflow run, monitor in-progress runs, and report failures with logs.
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
- **local-skill** — Download a single skill directory from a GitHub repository into the current project's `.claude/skills/`.
- **shortify** — Review and shorten markdown docs in subdirectories — cut wordiness, redundancy, and code duplication.

## References

See [docs/references.md](docs/references.md).
