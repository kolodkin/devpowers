---
name: action-check
description: Check the latest GitHub Actions workflow run result. Use when the user asks to check, inspect, or view the status of a workflow run (e.g. "/action-check pypi publish", "/action-check test").
---

# Action Check Skill

Check the latest run of a GitHub Actions workflow, report its result, and fix any failures automatically.

## Invocation Format

```
/action-check <workflow description>
```

Examples:
```
/action-check pypi publish
/action-check test
/action-check generate migration
```

## Step 1 — Identify the Workflow File

List available workflows:
```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify.

## Step 2 — Run the Script

```bash
./check.sh <workflow-file>
```

Examples:
```bash
./check.sh publish.yaml
./check.sh test.yaml
./check.sh generate-migration.yaml
```

The script will:
1. Install gh CLI if needed
2. Check authentication and read permissions
3. Find the latest run of the workflow
4. If the run is still in progress — monitor it to completion
5. On **success**: report the result
6. On **failure**: print full failed job logs

## Step 3 — Handle Failures

1. Read the error logs printed by the script
2. Fix the root cause (e.g. failing tests, bad inputs, version conflicts)
3. Commit and push fixes if needed
4. Use `/action-run` to trigger a new run

Only ask the user for input when the fix genuinely requires a decision. Otherwise fix and retry autonomously.
