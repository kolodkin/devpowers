---
name: action-run
description: Trigger and monitor any GitHub Actions workflow. Use when the user asks to run, trigger, or execute a GitHub Action (e.g. "/action-run pypi publish", "/action-run generate migration").
---

# Action Run Skill

Trigger any GitHub Actions `workflow_dispatch` workflow by name, gather required inputs, monitor it to completion, and fix failures automatically.

## Invocation Format

```
/action-run <workflow description> [key=value] [flag] ... [branch=<name>]
```

Examples:
```
/action-run pypi publish
/action-run pypi publish tag=v0.0.8 pre-release
/action-run pypi publish tag=v0.0.8 branch=main
/action-run generate migration message="add users table"
/action-run test
```

## Step 1 — Identify the Workflow File

List available workflows:
```bash
ls .github/workflows/
```

Match the user's description to a workflow file (fuzzy match by name/content). When ambiguous, ask the user to clarify.

## Step 2 — Discover Required Inputs

Read the matched workflow file:
```bash
cat .github/workflows/<file>
```

Find the `on.workflow_dispatch.inputs` section. For each input:
- **required: true** — must be provided before running
- **required: false** / no required field — optional, has default

## Step 3 — Gather Missing Inputs

Check which required inputs were **not** supplied in the invocation. Ask the user for any that are missing.

Inputs already provided in the invocation (as `key=value` or bare `flag`) are used as-is:
- `tag=v0.0.8` → `-f tag=v0.0.8`
- `pre-release` → `-f pre-release=true`

The `branch=<name>` argument is **not** a workflow input — it controls which branch the workflow runs on (`--ref`). By default the current git branch is used.

## Step 4 — Run the Script

```bash
./run.sh <workflow-file> [key=value|flag ...]
```

Examples:
```bash
./run.sh publish.yaml tag=v0.0.8 pre-release
./run.sh generate-migration.yaml message="add users table"
./run.sh test.yaml
```

The script will:
1. Install gh CLI if needed
2. Check authentication and write permissions
3. Detect if this workflow is already running — if so, monitor it instead of re-triggering
4. Trigger the workflow with the supplied inputs
5. Poll job status until completion
6. On **success**: report the result
7. On **failure**: print full failed job logs

## Step 5 — Handle Failures

1. Read the error logs printed by the script
2. Fix the root cause (e.g. failing tests, bad inputs, version conflicts)
3. Commit and push fixes if needed
4. Re-run the script with the same or corrected inputs

Only ask the user for input when the fix genuinely requires a decision (e.g. choosing a new version number). Otherwise fix and retry autonomously.

## Getting Logs for a Specific Run

```bash
gh run view <RUN_ID> --repo <OWNER/REPO> --log-failed
```
