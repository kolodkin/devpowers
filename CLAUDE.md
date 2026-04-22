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

- Reference bundled scripts from SKILL.md using `${CLAUDE_PLUGIN_ROOT}/...` so paths resolve correctly inside the plugin cache (`~/.claude/plugins/cache`). With the repo-as-plugin layout, `${CLAUDE_PLUGIN_ROOT}` is the repo root, so scripts live at `${CLAUDE_PLUGIN_ROOT}/skills/<name>/...`. This variable is substituted inline in skill content, hook commands, and MCP/LSP configs, and is also exported as an environment variable to subprocesses.
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
