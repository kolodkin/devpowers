---
name: skill-zip
description: Package a skill from a GitHub repo (or local path) into a zip that can be uploaded to claude.ai. Use when the user asks to prepare, build, pack, bundle, or zip a skill for claude.ai upload (e.g. "/skill-zip owner/repo", "/skill-zip https://github.com/owner/repo/tree/main/plugins/foo/skills/bar", "pack this skill for claude.ai").
---

# Skill Zip

Build a claude.ai-ready skill zip from a GitHub repo or local directory.

The script does **only** the packaging. Upload is manual — the user drops the zip into **claude.ai → Settings → Capabilities → Skills → Upload Skill**.

## Invocation Format

```
/skill-zip <repo-or-path> [--path <subdir>] [--ref <branch|tag|sha>] [--out <dir>] [--all]
```

Accepted `<repo-or-path>`:
- `owner/repo` (e.g. `anthropics/skills`)
- `https://github.com/owner/repo` or `.../repo.git`
- `https://github.com/owner/repo/tree/<ref>/<subpath>` — ref and subpath are parsed automatically
- `https://github.com/owner/repo/blob/<ref>/<subpath>/SKILL.md`
- A local directory path

Examples:
```
/skill-zip anthropics/skills --path document-skills/pdf
/skill-zip https://github.com/owner/repo/tree/main/skills/my-skill
/skill-zip ./plugins/skill-zip/skills/skill-zip
/skill-zip owner/repo --all --out ~/Downloads
```

## What the Script Does

```
${CLAUDE_PLUGIN_ROOT}/skills/skill-zip/pack.sh <repo-or-path> [flags]
```

1. Resolves the source (clones shallow to a temp dir if remote; parses `tree/<ref>/<path>` URLs).
2. Finds `SKILL.md` files (skips `.git`, `node_modules`, `__pycache__`, `.venv`).
3. Parses YAML frontmatter and validates:
   - `name` — required, matches `^[a-z0-9-]{1,64}$`, does not contain `anthropic` or `claude`
   - `description` — required, ≤1024 chars
4. Stages the skill folder as `<name>/` so the zip root is exactly `<name>/SKILL.md` (+ any sibling files). Excludes `.git`.
5. Writes `<name>.zip` to `--out` (default: current dir).
6. Fails if the zip exceeds **30 MB**.

If multiple `SKILL.md` files are found and neither `--path` nor `--all` is given, the script lists them and exits so the user can pick.

## After the Script Succeeds

Tell the user:
1. Open **https://claude.ai/settings/capabilities → Skills**.
2. Click **Upload Skill** (not the Directory modal — that's the official catalog).
3. Select the printed zip path and toggle the skill on.
4. Start a new chat and issue a triggering request; Claude should read `/mnt/skills/user/<name>/SKILL.md` before acting.
5. Prereqs: Pro / Max / Team / Enterprise plan, with **Code Execution and File Creation** + **Skills** toggled on under Capabilities.

## Re-publishing

claude.ai does not support in-place editing. After edits, re-run the skill to build a new zip, toggle the old upload off, and upload the new one.
