---
name: shortify
description: Review and shorten markdown docs, code comments, and docstrings — cut wordiness, redundancy, and code duplication. TRIGGER on .md file edits inside subdirectories, or when user asks to shorten/condense docs, comments, or docstrings. Skip root-level .md files (CLAUDE.md, README.md, CHANGELOG.md, etc.).
---

# shortify

Apply as a review pass after writing or editing `.md` files in subdirectories, or manually via `/shortify [file-or-glob]`.

**Scope**: Any `.md` file inside a subdirectory (e.g. `docs/`, `src/`), plus code comments and docstrings in source files.
**Skip**: `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `LICENSE.md`, and any root-level `.md` files — these have their own conventions.

If the project has its own convention, follow it. This overrides every rule below.

**Auto vs. manual**:
- **Markdown** triggers automatically as a review pass after `.md` edits in subdirectories.
- **Code comments & docstrings** are manual-only — never auto-triggered by a code edit. Run them on request: `/shortify <file-or-glob>` on source files, or when the user opts in for the session ("apply shortify to my comments this session"), after which apply it as a review pass to code you edit for the rest of that session.

## Checklist (markdown)

Apply in order:

**1. Kill Redundancy — Link, Don't Restate**

- Remove text and inline implementations that restate what code already shows. Link to the code instead.
- Link each doc–code pair once. By default the module docstring names its doc section, and the doc names a code path only when the reader must open it (an example file, a migration).
- A link names one module or package path: `See the storage/ package.` No functions, classes, private helpers, line numbers or file lists — they go stale fast.
- User guides: no implementation pointers. Code paths appear only inside prose that needs them.
- Design / architecture docs: optionally one module pointer under a heading.
- One example per concept. Delete duplicates. Keep short usage examples (3-5 lines); delete long inline code.
- API docs: call signature + one example, not internals.
- Merge overlapping sections — keep the clearer one.

**2. Cut Wordiness**

- Replace wordy phrases: "In order to" -> "To", "It is important to note that" -> delete, "This allows you to" -> delete or rephrase.
- Remove filler sentences that add no information.
- Prefer bullet lists over paragraphs for reference material.

**3. Tighten Structure**

- Delete empty/trivial sections. Merge one-sentence sections into neighbors.
- Shorten introductions — title + one sentence is enough.
- Flatten heading depth: `#` and `##` only. Avoid `###` and deeper — restructure instead.

**4. Check References**

- Grep every code path and symbol the doc names. Fix or drop any that no longer exist.
- When a section is merged, renamed or deleted, grep the repo for the old heading text. Code back-links quote headings word for word, so update them too.

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
- Doc back-links (`See docs/...`), in one block right after the docstring's summary line, linking one or two docs at most. Flag any link whose quoted heading no longer exists in the doc.

  ```python
  """Kubernetes runner.

  See docs/designs/kubernetes_runner.md.
  See docs/designs/orchestration.md — "Execution layers".

  Drives Pods via drive_vehicle.
  """
  ```
- Anything load-bearing for behavior or tooling — when unsure, leave it.

## Output

Show before/after line count and a brief summary of cuts. Commit if approved.
