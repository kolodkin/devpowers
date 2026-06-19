---
name: shortify
description: Review and shorten markdown docs, code comments, and docstrings — cut wordiness, redundancy, and code duplication. TRIGGER on .md file edits inside subdirectories, or when user asks to shorten/condense docs, comments, or docstrings. Skip root-level .md files (CLAUDE.md, README.md, CHANGELOG.md, etc.).
---

# shortify

Apply as a review pass after writing or editing `.md` files in subdirectories, or manually via `/shortify [file-or-glob]`.

**Scope**: Any `.md` file inside a subdirectory (e.g. `docs/`, `src/`), plus code comments and docstrings in source files.
**Skip**: `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `LICENSE.md`, and any root-level `.md` files — these have their own conventions.

**Auto vs. manual**:
- **Markdown** triggers automatically as a review pass after `.md` edits in subdirectories.
- **Code comments & docstrings** are manual-only — never auto-triggered by a code edit. Run them on request: `/shortify <file-or-glob>` on source files, or when the user opts in for the session ("apply shortify to my comments this session"), after which apply it as a review pass to code you edit for the rest of that session.

## Checklist (markdown)

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

## Checklist (code comments & docstrings)

Cut redundancy, keep intent. Change comment/docstring **text only** — never logic.

**1. Delete the "what", keep the "why"**

- Remove comments that restate the code: `i += 1  # increment i`, `# constructor`, `# return result`.
- Keep comments that explain *why* — intent, rationale, non-obvious decisions, gotchas, genuine warnings.
- Collapse a multi-line comment that says one thing into one line.

**2. Tighten docstrings**

- Keep the contract: one-line summary + params/returns/raises per the project's convention.
- Don't repeat type info already in the signature or annotations.
- At most one example, and only when it adds something the signature doesn't.
- Apply the same wordiness cuts as markdown (see "Cut Wordiness" above).

**3. Preserve**

- Tooling directives: `# noqa`, `# type: ignore`, `eslint-disable`, `# pragma`, shebangs, encoding lines.
- License/copyright headers, `TODO`/`FIXME`, doctest examples, and public-API docs required by convention.
- Anything load-bearing for behavior or tooling — when unsure, leave it.

## Output

Show before/after line count and a brief summary of cuts. Commit if approved.
