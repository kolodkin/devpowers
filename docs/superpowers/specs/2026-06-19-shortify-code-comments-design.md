# Design: extend `shortify` to code comments & docstrings

## Goal

Extend the `shortify` skill — today scoped to markdown docs — to also shorten
**code comments and docstrings** in source files, applying the same
"cut redundancy, cut wordiness" philosophy adapted to code.

## Triggers

- **Markdown auto-trigger is unchanged**: fires as a review pass on `.md` edits
  inside subdirectories.
- **Code is manual-only.** It is never auto-triggered by a code edit. It runs
  when:
  - the user invokes `/shortify <file-or-glob>` on source files, or
  - the user opts in for the session ("apply shortify to my code comments this
    session") — then it runs as a review pass after code edits for the rest of
    that session.

## Philosophy for comments & docstrings (why-not-what)

- **Delete comments that restate the code** (the "what") — e.g. `i += 1  # increment i`.
- **Keep the "why"** — intent, rationale, non-obvious decisions, gotchas, genuine warnings.
- **Docstrings**: keep the contract (summary + params/returns/raises per project
  convention) and at most one example; cut wordiness; don't repeat type info
  already in the signature.
- **Cut wordiness** in comment/docstring prose using the same phrase-level rules
  as markdown.

## Preserve (do NOT touch)

- Tooling directives: `# noqa`, `# type: ignore`, `eslint-disable`, `# pragma`, etc.
- License/copyright headers, `TODO`/`FIXME`, doctest examples, public-API docs
  required by convention.
- **Code behavior** — only comment/docstring *text* changes, never logic.

## Output

Unchanged: show before/after line count and a brief summary of cuts; commit if approved.
