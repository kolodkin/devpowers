---
name: jira-setup
description: >
  Ensure the mcp-atlassian MCP server is registered and resolve Jira
  defaults (URL, auth, project, board) so the jira-ticket skill has
  everything it needs. Idempotent — re-runs only prompt for whatever is
  missing. Use when the user wants to set up or reconfigure Jira, install /
  register mcp-atlassian, pick a default project or board, or persist Jira
  env vars to their shell rc. Also invoked automatically by the jira-ticket
  skill when required env vars are missing.
  Triggers on: "/jira-setup", "set up jira", "configure jira",
  "install mcp-atlassian", "pick jira project", "pick jira board".
---

# Jira Setup

Walk through the steps below and prompt only for what's missing. Re-running this is safe — values that are already set are reported and skipped.

## Step 0 — Ensure the mcp-atlassian MCP server is registered

This skill (and `jira-ticket`) drive Jira through the `mcp__mcp-atlassian__*` tools. Check whether `mcp__mcp-atlassian__jira_create_issue` is visible in your tool list.

- **If it's visible**, the server is registered. Skip to Step 1.
- **If it's missing**, hand off to the `setup-mcp` skill, which is the bounded installer for this plugin's MCP servers — `mcp-atlassian` is already in its manifest. **Invoke `setup-mcp` via the Skill tool with `mcp-atlassian`** (e.g. `/setup-mcp mcp-atlassian`). It shows the proposed config, asks for scope, registers the server, and verifies the `uvx` prerequisite. Because MCP servers only load at startup, it will tell the user to restart Claude Code — so once it returns, tell the user to **restart and re-run `/jira-setup`** (or `/jira-ticket`), then stop. The tools won't be available until the restart.

  If the `setup-mcp` skill isn't available in this session for any reason, fall back to instructing the user: "Run `/setup-mcp mcp-atlassian`, restart Claude Code, then re-run `/jira-setup`."

## Step 1 — Validate credentials

Run this exact command:
```bash
echo "JIRA_URL=${JIRA_URL:-NOT_SET}" && \
echo "JIRA_USERNAME=${JIRA_USERNAME:-NOT_SET}" && \
echo "JIRA_API_TOKEN=${JIRA_API_TOKEN:+SET}" && \
echo "JIRA_PERSONAL_TOKEN=${JIRA_PERSONAL_TOKEN:+SET}"
```

`JIRA_URL` is always required. For auth, **either** the Cloud combo (`JIRA_USERNAME` + `JIRA_API_TOKEN`) **or** the Server / Data Center PAT (`JIRA_PERSONAL_TOKEN`) must be set. If neither is complete, instruct the user and stop. Do not proceed.

- `JIRA_URL` is `NOT_SET` → "Set your Jira workspace URL, e.g. `export JIRA_URL=https://yourworkspace.atlassian.net`"
- **Cloud** (Atlassian-hosted, `*.atlassian.net`): set both
  - `JIRA_USERNAME` → your account email, e.g. `export JIRA_USERNAME=you@example.com`
  - `JIRA_API_TOKEN` → create one at https://id.atlassian.com/manage-profile/security/api-tokens, then `export JIRA_API_TOKEN=<your-token>`
- **Server / Data Center** (self-hosted): set just
  - `JIRA_PERSONAL_TOKEN` → create a Personal Access Token in your Jira profile, then `export JIRA_PERSONAL_TOKEN=<your-pat>`. `JIRA_USERNAME` is optional here, but if you set it the jira-ticket skill will use it for the assignee / reporter on created tickets.

The `mcp-atlassian` server reads these from the shell that launched Claude Code, so encourage the user to add the relevant exports to their `~/.zshrc` or `~/.bashrc` and restart Claude Code so the server picks them up.

## Step 2 — Resolve project (auto-discover if needed)

Check `$JIRA_PROJECT_KEY`:
```bash
echo "JIRA_PROJECT_KEY=${JIRA_PROJECT_KEY:-NOT_SET}"
```

If set, report the resolved value and move on. If `NOT_SET`:

1. Call `mcp__mcp-atlassian__jira_get_all_projects` to list available projects.
2. Present them to the user as a numbered list of `KEY — Name` (e.g., `1. PROJ — My Project`). If there are many, group/sort sensibly.
3. Ask the user to pick one.
4. Treat the picked key as the resolved `$JIRA_PROJECT_KEY` for the rest of this run.
5. Offer to persist: "Save `JIRA_PROJECT_KEY=<KEY>` to your shell rc so you don't have to pick again next time? (yes/no)"
6. If yes → follow the **Persisting to shell rc** procedure below with `VAR_NAME=JIRA_PROJECT_KEY` and `VAR_VALUE=<picked key>`.

## Step 3 — Resolve board (optional, for sprint placement)

This is only needed if the user wants to place tickets into sprints. If this skill is being invoked from `jira-ticket` and no sprint argument was passed, you can skip this step. Otherwise, offer to set it up so future sprint placements work without prompting.

Check `$JIRA_BOARD_ID`:
```bash
echo "JIRA_BOARD_ID=${JIRA_BOARD_ID:-NOT_SET}"
```

If set, report it and move on. If `NOT_SET`:

1. Call `mcp__mcp-atlassian__jira_get_agile_boards` filtered by the resolved project key.
2. Present them to the user as a numbered list of `ID — Name (Type)` (e.g., `1. 6 — Engineering Scrum (scrum)`).
3. Ask the user to pick one.
4. Treat the picked id as the resolved `$JIRA_BOARD_ID` for the rest of this run.
5. Offer to persist: "Save `JIRA_BOARD_ID=<ID>` to your shell rc? (yes/no)"
6. If yes → follow the **Persisting to shell rc** procedure below with `VAR_NAME=JIRA_BOARD_ID` and `VAR_VALUE=<picked id>`.

If the project has no boards, tell the user and skip — sprint placement won't be available until a board exists.

## Persisting to shell rc

When the user agrees to persist a value, detect the right rc file, check whether the export is already present, and append only if missing. Run:

```bash
VAR_NAME=JIRA_PROJECT_KEY   # or JIRA_BOARD_ID
VAR_VALUE=PROJ               # the picked value

case "$(basename "${SHELL:-}")" in
  zsh)  RC=~/.zshrc ;;
  bash) RC=~/.bashrc ;;
  *)    RC=~/.profile ;;
esac

touch "$RC"
if grep -qE "^export[[:space:]]+${VAR_NAME}=" "$RC"; then
  echo "${VAR_NAME} is already exported in $RC — leaving it alone. Update it manually if you want a different value."
else
  echo "export ${VAR_NAME}=${VAR_VALUE}" >> "$RC"
  echo "Added 'export ${VAR_NAME}=${VAR_VALUE}' to $RC"
fi
```

Then tell the user: "The current session is already using `<value>`. New shells will pick it up automatically; for an existing shell, run `source $RC`."

## Final summary

After all applicable steps complete, print a one-line readiness summary so the user knows what's wired up:

```
Jira ready ✓
  URL:       <JIRA_URL>
  Auth:      <Cloud (JIRA_USERNAME) | Server/DC (JIRA_PERSONAL_TOKEN)>
  Project:   <JIRA_PROJECT_KEY>
  Board:     <JIRA_BOARD_ID or "not set — sprint placement unavailable">
```

If anything required is still missing, list what's missing and how to set it instead of claiming readiness.
