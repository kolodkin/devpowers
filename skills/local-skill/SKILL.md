---
name: local-skill
description: Download, update, or dry-run-preview a single skill directory from a GitHub repository in the current project's ./.claude/skills/ folder. Use when the user asks to install, add, fetch, download, update, or preview a local skill from a repo (e.g. "/local-skill anthropics/skills skills/pdf", "update the pdf skill", "dry-run the action-run skill from kolodkin/devpowers").
---

# Local Skill

Install or update a skill from a public GitHub skills repository into the current project's `.claude/skills/<skill-name>/`. The installer fetches the repo's latest tarball from `codeload.github.com`, extracts just `<skill-path>/` into the destination, and discards the rest. No GitHub API calls (so no 60 req/hr rate limit), no `git` required, no `.git` left in the destination.

An install writes a small `.local-skill.stamp` file into the skill directory recording `{repo, path}`. Commit this file alongside the skill so anyone with the repo can later run `update` to pull the latest version.

## Invocation Format

```
/local-skill <repo> <skill-path> [--force] [--dry-run]
/local-skill update <skill-name> [--dry-run]
```

- `<repo>` — `owner/repo` slug or a full `https://github.com/owner/repo(.git)` URL.
- `<skill-path>` — path of the skill directory within the repo (e.g. `pdf`, `skills/pdf`, or any deeper path).
- `<skill-name>` — basename of an already-installed skill under `.claude/skills/`.
- `--force` — overwrite an existing destination directory (install only).
- `--dry-run` — fetch the tree and print the file list that would be installed; do not create or modify anything on disk. When the user says "dry run", "preview", "evaluate", "show me what would happen", or similar, pass this flag.

Examples:

```
/local-skill anthropics/skills skills/pdf
/local-skill anthropics/skills skills/docx --dry-run
/local-skill kolodkin/devpowers skills/action-run --dry-run
/local-skill update pdf
/local-skill update pdf --dry-run
```

## Install flow

1. The user must supply both `<repo>` and `<skill-path>`. If either is missing, ask — don't guess.
2. Run the downloader from the project root so `.claude/skills/` lands in the user's project:

   ```bash
   bash scripts/download.sh <repo> <skill-path> [--force] [--dry-run]
   ```

   Pass `--force` only if the user explicitly asked to overwrite. Pass `--dry-run` if the user asked to preview / evaluate / not actually install — the script will fetch the tree and print the file list without writing anything.

3. After success, show the user what was installed and surface the new skill's name/description:

   ```bash
   ls -la .claude/skills/<basename>
   sed -n '1,20p' .claude/skills/<basename>/SKILL.md
   ```

## Update flow

When the user asks to update an already-installed skill, run:

```bash
bash scripts/update.sh <skill-name> [--dry-run]
```

This reads `.claude/skills/<skill-name>/.local-skill.stamp`, re-fetches the latest HEAD from the recorded repo/path, and replaces the skill directory in place. Pass `--dry-run` to preview what would change without modifying the installed skill — the flag is forwarded to `download.sh`.

If there is no stamp file, the skill wasn't installed via `local-skill` — surface that and ask the user for the repo/path to install fresh instead.

## Notes

- Destination folder name is the basename of `<skill-path>` — e.g. `skills/pdf` installs to `.claude/skills/pdf/`.
- Update always overwrites local edits. Warn the user if `.claude/skills/<name>/` has uncommitted changes before updating.
- Public GitHub repos only; always tracks the default branch's HEAD (no pinning).
- Downloads via `codeload.github.com` (the same infrastructure that serves GitHub's "Download ZIP" archive links). No GitHub API calls, so no rate limit — but the full repo tarball is fetched each time, so point this at repos where the skill dir is a reasonable fraction of total size.
