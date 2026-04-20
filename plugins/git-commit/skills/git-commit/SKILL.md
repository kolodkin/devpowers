---
name: git-commit
description: Create a git commit with staged changes, handling pre-commit hooks automatically. Use when the user asks to commit, make a commit, or create a commit (e.g. "/git-commit", "/git-commit fix login bug").
---

# Git Commit Skill

Create a git commit with the user's staged changes using the project's commit type convention, and handle pre-commit hook modifications safely.

## Invocation Format

```
/git-commit [optional commit message]
```

Examples:
```
/git-commit
/git-commit fix login redirect loop
/git-commit add user profile endpoint
```

## Step 1 — Inspect Staged Changes

Run these in parallel:

```bash
git diff --staged --name-only
git diff --staged
```

Use `--name-only` output as the authoritative list of originally staged files — you will need it verbatim if a pre-commit hook modifies files. Use the full staged diff to draft the commit message.

If the output of `--name-only` is empty, stop and tell the user nothing is staged — do NOT run `git add` on their behalf.

If `git status` reveals a mid-rebase, mid-merge, mid-cherry-pick, or detached HEAD, stop and surface that to the user before committing.

## Step 2 — Determine the Commit Message

If the user supplied a message in the invocation:

- If it already has a recognized type prefix (e.g. `feature:`, `bugfix:`), use it verbatim.
- If it's a bare phrase, prepend the most appropriate type based on the staged diff (see types below).
- Preserve any multi-line body the user provided.

Otherwise, analyze the staged diff and draft a message using this project's type convention:

- `feature:` — new features
- `bugfix:` — bug fixes
- `refactor:` — code refactoring
- `cleanup:` — code cleanup

Multiple types can be combined when appropriate, e.g. `[feature, cleanup]: description`.

Message structure:

```
<type>: <short description>

<optional longer description>
```

Keep the subject line concise (target 50 chars, hard wrap at 72) and focus the body on the "why".

## Step 3 — Get User Approval

Show the proposed message to the user and wait for approval before committing. Let them edit it. Skip this step only if the user supplied a complete message (subject + body, or an explicit "commit as-is" instruction).

## Step 4 — Create the Commit

Commit with a HEREDOC and chain the result display in the same call to save a round-trip:

```bash
git commit -m "$(cat <<'EOF'
<type>: <short description>

<optional longer description>
EOF
)" && git log -1 --pretty=format:"%h %s%n%b"
```

## Step 5 — Handle Pre-commit Hook Failures

If the commit failed, inspect the hook output to decide which case applies.

### Case A: Hooks modified files (formatters, auto-fixers)

No commit was created. Re-stage **only the files from Step 1's `--name-only` list** — not every modified file — and retry with the same message chained to `git log -1`:

```bash
git add file1.py file2.py file3.py
git commit -m "$(cat <<'EOF'
<same commit message>
EOF
)" && git log -1 --pretty=format:"%h %s%n%b"
```

Do NOT use `git add -u` (stages every modified tracked file, including unrelated changes). Do NOT use `--amend` (there is no commit to amend).

If hooks modify files again on retry, try once more. If they keep modifying files after that, stop and surface the non-convergence to the user.

### Case B: Hooks rejected the commit without modifying files (lint, type-check, test failures)

Nothing to re-stage. Fix the underlying issue the hook reported, re-stage the fixed files, then retry Step 4. If the failure is in code you didn't touch, surface it to the user instead of silently patching unrelated files.

## Notes

- If amending would be unsafe (commit authored by someone else, or already pushed), create a NEW commit instead of amending.
- Do NOT include "Generated with …" footers or co-author trailers unless the user asks.
- Do NOT push after committing unless the user asks.
