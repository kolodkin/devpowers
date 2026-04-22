---
name: local-skill
description: Download or update a single skill directory from a GitHub repository in the current project's ./.claude/skills/ folder. Use when the user asks to install, add, fetch, download, or update a local skill from a repo (e.g. "/local-skill anthropics/skills skills/pdf", "update the pdf skill").
---

# Local Skill

Install or update a skill from a public GitHub skills repository into the current project's `.claude/skills/<skill-name>/`. The installer queries the GitHub git-trees API for the repo's file list, filters to `<skill-path>/`, and downloads only those blobs via `raw.githubusercontent.com` — the rest of the repo is never transferred. No `git` required, no `.git` left in the destination.

An install writes a small `.local-skill.stamp` file into the skill directory recording `{repo, path, installed_at}`. Commit this file alongside the skill so anyone with the repo can later run `update` to pull the latest version.

## Invocation Format

```
/local-skill <repo> <skill-path> [--force]
/local-skill update <skill-name>
```

- `<repo>` — `owner/repo` slug or a full `https://github.com/owner/repo(.git)` URL.
- `<skill-path>` — path of the skill directory within the repo (e.g. `pdf`, `skills/pdf`, or any deeper path).
- `<skill-name>` — basename of an already-installed skill under `.claude/skills/`.
- `--force` — overwrite an existing destination directory (install only).

Examples:

```
/local-skill anthropics/skills skills/pdf
/local-skill anthropics/skills skills/docx
/local-skill obra/superpowers skills/debugging
/local-skill update pdf
```

## Install flow

1. The user must supply both `<repo>` and `<skill-path>`. If either is missing, ask — don't guess.
2. Run the downloader from the project root so `.claude/skills/` lands in the user's project:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/local-skill/scripts/download.sh" <repo> <skill-path>
   ```

   Pass `--force` only if the user explicitly asked to overwrite.

3. After success, show the user what was installed and surface the new skill's name/description:

   ```bash
   ls -la .claude/skills/<basename>
   sed -n '1,20p' .claude/skills/<basename>/SKILL.md
   ```

The script validates inputs, creates `.claude/skills/` if needed, fetches the repo tree JSON, downloads each blob under `<skill-path>/` into the destination (preserving executable mode), and writes `.local-skill.stamp`. It refuses to overwrite without `--force`.

## Update flow

When the user asks to update an already-installed skill, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/local-skill/scripts/update.sh" <skill-name>
```

This reads `.claude/skills/<skill-name>/.local-skill.stamp`, re-fetches the latest HEAD from the recorded repo/path, and replaces the skill directory in place. The stamp's `installed_at` is then refreshed.

If there is no stamp file, the skill wasn't installed via `local-skill` — surface that and ask the user for the repo/path to install fresh instead.

## Notes

- Destination folder name is the basename of `<skill-path>` — e.g. `skills/pdf` installs to `.claude/skills/pdf/`.
- The `.local-skill.stamp` file is intended to be committed. Updates rely on it; without it, there is no way to know where the skill came from.
- Update always overwrites local edits to the skill directory. Warn the user if `.claude/skills/<name>/` has uncommitted changes and they've asked for an update.
- Requires `curl` and `python3` on PATH. No `git` or `tar` dependency.
- Only public GitHub repositories are supported.
- Always fetches latest HEAD of the default branch; pinning to a specific commit or branch is not supported.
- Uses the unauthenticated GitHub API (60 requests/hour per IP). Installing one skill = one API call + N raw file downloads (raw downloads are not API-rate-limited).
- Git-trees API returns a truncated response for very large repos (>100k entries); in that case the installer errors out with a clear message.
- On failure, scripts print a clear error to stderr and exit non-zero — relay the message rather than retrying silently.
