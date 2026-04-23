# CLAUDE.md

This repository is a Claude Code **plugin** that is also its own single-plugin marketplace. The repo root *is* the plugin root: `.claude-plugin/plugin.json` is the plugin manifest, and `.claude-plugin/marketplace.json` catalogs it with `"source": "./"`. Component directories (`skills/`, `commands/`, `agents/`, `hooks/`) live at the repo root.

## Layout

```
.claude-plugin/
  marketplace.json              # marketplace catalog (source: "./")
  plugin.json                   # plugin manifest
skills/<skill-name>/
  SKILL.md                      # skill entry point
  ...                           # optional scripts, references
```

## Conventions

- Reference bundled scripts from SKILL.md using plain relative paths (e.g. `./check.sh`, `scripts/download.sh`). Claude resolves them against the skill's install directory, so the same SKILL.md works for both plugin installs (under `~/.claude/plugins/cache/.../skills/<name>/`) and project-level installs (under `<project>/.claude/skills/<name>/`). Avoid `${CLAUDE_PLUGIN_ROOT}` inside skill bodies — it's empty when the skill is installed project-level, and `${CLAUDE_PROJECT_DIR}` isn't reliably set in Bash tool invocations either ([anthropics/claude-code#6023](https://github.com/anthropics/claude-code/issues/6023)). Reserve `${CLAUDE_PLUGIN_ROOT}` for `hooks/*.json` and MCP/LSP configs, where the harness guarantees it's set.
- Use `${CLAUDE_PLUGIN_DATA}` for state that must survive plugin updates.
- All component directories (`skills/`, `commands/`, `agents/`, `hooks/`) live at the plugin root — never inside `.claude-plugin/`.

## References

See [docs/references.md](docs/references.md).

Docs:
- [Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Skills](https://code.claude.com/docs/en/skills)

Reference repositories to study:
- [anthropics/skills](https://github.com/anthropics/skills) — Anthropic's public skills
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Official marketplace, including the `plugin-dev` plugin with `plugin-structure` and `hook-development` skills
- [anthropics/claude-code `plugins/`](https://github.com/anthropics/claude-code/tree/main/plugins) — Reference plugins shipped with Claude Code
- [travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) — Curated list
- [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins) — Curated list
