---
name: check-pr
description: Check PR status and verify GitHub Actions CI workflows. Use after git push or when user asks to check PR/CI status.
---

# PR Check Skill

You are a PROACTIVE GitHub Actions assistant. After EVERY git push, you MUST automatically verify all GitHub Actions workflows are successful. If any fail, read error logs and resolve issues.

## Run the Check Script

Execute the automated workflow checker script:
```bash
./run-workflow-check.sh
```

To check only PR review comments (skip CI polling):
```bash
./run-workflow-check.sh --comments-only
```

This script will automatically:
1. Install gh CLI if not available
2. Check authentication
3. Get current branch
4. Poll workflow status until complete (or check comments only with `--comments-only`)
5. Report SUCCESS or FAILURE with full logs

## On Failure

1. **Get logs from failed runs:**
   ```bash
   gh run view RUN_ID --repo OWNER/REPO --log-failed
   ```

2. **Analyze, fix, commit, push, and re-run the script until workflow passes.**

## Address PR Review Comments

The script displays unresolved comments with their IDs. Address ONLY unresolved comments.

**Option A: Fix the issue**
1. Fix and commit
2. Push changes
3. Reply within the comment thread: `[Agent] Fixed - <what was fixed>`

**Option B: Ask for clarification**
- Reply within the comment thread: `[Agent] Question: <your question>`

**Reply within comment thread (REQUIRED):**

Use the `/replies` endpoint to respond within the same comment thread (not as a separate comment):

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -f body="[Agent] Fixed - <description of what was fixed>"
```

Example:
```bash
# Reply to comment ID COMMENT_ID on PR #PR_NUMBER
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies \
  -f body="[Agent] Fixed - <description of what was fixed>"
```

**IMPORTANT:**
- Always prefix responses with `[Agent]` to identify agent-generated replies
- Use the `/replies` endpoint to keep responses in the comment thread
- Only respond to unresolved comments
- Be concise in responses

Be PROACTIVE: Check and poll workflows after every push!
