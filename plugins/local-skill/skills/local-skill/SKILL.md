---
name: local-skill
description: Download a single skill directory from a GitHub repository into the current project's ./.claude/skills/ folder. Use when the user asks to install, add, fetch, or download a skill locally from a repo (e.g. "/local-skill anthropics/skills pdf", "install the docx skill from anthropics/skills").
---

# Local Skill

Download one skill from a GitHub skills repository into the current project's `.claude/skills/<skill-name>/`. Only the requested subdirectory is fetched (via `git sparse-checkout`), so this stays light even for large skill repos.

## Invocation Format

```
/local-skill <repo> <skill-name> [--force]
```

- `<repo>` — `owner/repo` slug or a full `https://github.com/owner/repo(.git)` URL.
- `<skill-name>` — path of the skill directory within the repo (e.g. `pdf`, `skills/pdf`, or any deeper path).
- `--force` — overwrite an existing destination directory.

Examples:

```
/local-skill anthropics/skills pdf
/local-skill anthropics/skills docx
/local-skill obra/superpowers skills/debugging
/local-skill https://github.com/anthropics/skills pdf --force
```

## Step 1 — Parse arguments

The user must supply both `<repo>` and `<skill-name>`. If either is missing, ask for it before proceeding — do not guess.

## Step 2 — Run the downloader

Invoke the bundled script from the current working directory (so `.claude/skills/` lands in the user's project):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/local-skill/scripts/download.sh" <repo> <skill-name>
```

Pass `--force` only if the user explicitly asked to overwrite.

The script:

- Validates `<repo>` and `<skill-name>`.
- Creates `.claude/skills/` if it does not exist.
- Uses a shallow, blobless sparse clone to fetch only `<skill-name>` from the repo.
- Refuses to overwrite an existing `.claude/skills/<basename>` unless `--force` is passed.
- Prints the install path on success.

## Step 3 — Confirm the result

After the script succeeds, show the user what was installed:

```bash
ls -la .claude/skills/<basename-of-skill-name>
```

If the directory contains a `SKILL.md`, read the first ~20 lines and surface the `name` and `description` so the user can verify they got the right skill.

## Notes

- The destination folder name is the basename of `<skill-name>` — e.g. `skills/pdf` installs to `.claude/skills/pdf/`.
- Requires `git` on PATH.
- On failure, the script prints a clear error to stderr and exits non-zero — relay the message to the user rather than retrying silently.
