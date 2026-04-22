---
name: shortify
description: Review and shorten markdown docs — cut wordiness, redundancy, and code duplication. TRIGGER on .md file edits inside subdirectories, or when user asks to shorten/condense docs. Skip root-level .md files (CLAUDE.md, README.md, CHANGELOG.md, etc.).
---

# shortify

Apply as a review pass after writing or editing `.md` files in subdirectories, or manually via `/shortify [file-or-glob]`.

**Scope**: Any `.md` file inside a subdirectory (e.g. `docs/`, `src/`).
**Skip**: `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `LICENSE.md`, and any root-level `.md` files — these have their own conventions.

## Checklist

Apply in order:

**1. Kill Redundancy**

- Remove text that restates what code already shows — link to the source instead.
- One example per concept. Delete duplicates.
- Merge overlapping sections — keep the clearer one.

**2. Cut Wordiness**

- Replace wordy phrases: "In order to" -> "To", "It is important to note that" -> delete, "This allows you to" -> delete or rephrase.
- Remove filler sentences that add no information.
- Prefer bullet lists over paragraphs for reference material.

**3. Tighten Structure**

- Delete empty/trivial sections. Merge one-sentence sections into neighbors.
- Shorten introductions — title + one sentence is enough.
- Flatten heading depth: `#` and `##` only. Avoid `###` and deeper — restructure instead.

**4. Reference Code, Don't Duplicate**

- Replace inline implementations with references: `See DataContext.query() in aaiclick/data/data_context.py.`
- Keep short usage examples (3-5 lines). Delete long inline code.
- API docs: call signature + one example, not internals.

**5. Preserve**

- Content with no other source (design decisions, rationale, gotchas).
- Non-obvious usage examples and genuine `!!! warning` admonitions.
- Do NOT change referenced code — only the surrounding text.

## Output

Show before/after line count and a brief summary of cuts. Commit if approved.
