# devpowers

A Claude Code plugin bundling developer productivity skills.

## Install

```
/plugin marketplace add kolodkin/devpowers
/plugin install devpowers@devpowers
```

## Skills

- **action-run** — Trigger and monitor any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, and fix failures automatically.
- **action-check** — Check the latest GitHub Actions workflow run, monitor in-progress runs, and report failures with logs.
- **git-commit** — Create a git commit with staged changes, handling pre-commit hooks automatically.
- **local-skill** — Download a single skill directory from a GitHub repository into the current project's `.claude/skills/`.

## References

Docs:
- [Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Skills](https://code.claude.com/docs/en/skills)

Official plugin/skill repositories:
- [anthropics/skills](https://github.com/anthropics/skills) — Anthropic's public skills repository
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Official plugin marketplace (includes `plugin-dev`)
- [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins) — Reference plugins shipped with Claude Code

Community marketplaces and curated lists:
- [travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) — Curated list of skills and tools
- [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins) — Curated list of plugins
- [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) — 232+ skills across multiple coding agents
- [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills) — Large marketplace with package manager
