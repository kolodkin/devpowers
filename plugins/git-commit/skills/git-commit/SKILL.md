---
name: git-commit
description: Create a git commit with staged changes, handling pre-commit hooks automatically. Use when the user asks to commit, make a commit, or create a commit (e.g. "/git-commit", "/git-commit fix login bug").
---

# Git Commit Skill

Create a git commit with the user's staged changes, following conventional commit format and handling pre-commit hook modifications safely.

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

## Pre-commit Hook Context

Some projects use pre-commit hooks that modify files during commit (formatting, linting, etc.). When hooks modify files, the commit fails and must be retried after re-staging.

## Step 1 — Inspect Staged Changes

Run these in parallel to understand what's being committed:

```bash
git status
git diff --staged --stat
```

If nothing is staged, stop and tell the user — do NOT run `git add` on their behalf.

Record the exact list of originally staged files. You will need it if a pre-commit hook modifies files.

## Step 2 — Determine the Commit Message

If the user supplied a message in the invocation, use it as-is (only reformat to conventional style if it obviously fits a single type).

Otherwise, analyze the staged diff and draft a message using conventional commit format:

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

Keep the subject line concise (ideally ≤72 chars). Focus on the "why" in the body when useful.

## Step 3 — Get User Approval

Present the proposed commit message to the user and ask for approval before committing. Let them edit it if needed. **Do not** skip this step, even when the user supplied a message — confirm before creating the commit.

## Step 4 — Create the Commit

Use a HEREDOC so multi-line messages format correctly:

```bash
git commit -m "$(cat <<'EOF'
<type>: <short description>

<optional longer description>
EOF
)"
```

## Step 5 — Handle Pre-commit Hook Modifications

If the commit **failed** because pre-commit hooks modified files:

- The hooks ran BEFORE the commit was created, so no commit exists yet.
- Re-stage **only the files that were originally staged** — not every modified file.
- Do NOT use `git add -u` (stages all modified tracked files, including unrelated changes).
- Do NOT use `--amend` (there is no commit to amend).

Re-stage by explicit file list, then retry with the same message:

```bash
git add file1.py file2.py file3.py
git commit -m "$(cat <<'EOF'
<same commit message>
EOF
)"
```

If hooks modify files again, repeat once more. If they keep modifying files, stop and surface the issue to the user.

## Step 6 — Show the Result

After a successful commit, display it:

```bash
git log -1 --pretty=format:"%h %s%n%b"
```

## Important Notes

- **NEVER** amend commits authored by someone else or already pushed.
- If amending is unsafe, create a NEW commit instead.
- **ALWAYS** use HEREDOC for multi-line commit messages.
- **ALWAYS** get user approval before creating the commit.
- Do **NOT** include "Generated with ..." footers or co-author trailers in commit messages unless the user explicitly asks for them.
- Do **NOT** push after committing unless the user asks.
