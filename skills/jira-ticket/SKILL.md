---
name: jira-ticket
description: >
  Create or comment on Jira tickets in your configured project with structured descriptions.
  Use when the user wants to open, create, or file a Jira ticket, bug, task, or story,
  OR when they want to add a technical comment to an existing ticket.
  Triggers on: "/jira-ticket", "open a jira ticket", "create a jira bug", "file a task",
  "comment on PROJ-1234", or any request to create/comment on a Jira issue.
  Two modes: create (default) and comment (when an issue key is provided).
  Examples: "/jira-ticket bug, current", "/jira-ticket PROJ-1234".
---

# Jira Ticket — Create or Comment

Two modes, one content engine. The presence of a Jira issue key in the arguments determines the mode.

## Prerequisites

Resolve required values in four steps. The MCP server is auto-installed on first use; credentials must be set up by the user; project and board are auto-discovered from Jira and offered for one-time persistence.

### Step 0 — Ensure the mcp-atlassian MCP server is available

This skill drives Jira through the `mcp__mcp-atlassian__*` tools. Before anything else, check whether those tools are present in the current session.

- **If `mcp__mcp-atlassian__jira_create_issue` is visible in your tool list**, the server is already configured. Skip to Step 1.
- **If it's missing**, offer to register the server in the project's `.mcp.json`:

  1. Show the user exactly what would be added (so they can review before any file is written):
     ```json
     {
       "mcpServers": {
         "mcp-atlassian": {
           "command": "uvx",
           "args": ["mcp-atlassian"]
         }
       }
     }
     ```
     The MCP server inherits Jira credentials (`JIRA_URL` plus either `JIRA_USERNAME` + `JIRA_API_TOKEN` for Cloud or `JIRA_PERSONAL_TOKEN` for Server / Data Center) from the shell that launched Claude Code — no `env` block is needed in `.mcp.json` (and `${VAR}` expansion in MCP env values is unreliable across versions, so don't depend on it). See https://github.com/sooperset/mcp-atlassian for Confluence support and Docker / pipx alternatives if `uvx` isn't available.

  2. Ask: "Add this to `./.mcp.json`? (yes/no)"

  3. If **yes**:
     - Read `./.mcp.json` if it exists.
     - If it doesn't exist, write the snippet above as-is.
     - If it exists, parse it, merge the `mcp-atlassian` entry into the existing `mcpServers` object **without clobbering other servers or other top-level keys**, and write the result back. Preserve formatting where reasonable (2-space indent, trailing newline).
     - If `mcpServers["mcp-atlassian"]` already exists with a different config, ask before overwriting.

  4. Verify `uvx` is installed:
     ```bash
     command -v uvx >/dev/null && echo "uvx OK" || echo "uvx MISSING"
     ```
     If missing, tell the user: "Install `uv` first: `curl -LsSf https://astral.sh/uv/install.sh | sh` (or use Docker / pipx — see the mcp-atlassian README)."

  5. Tell the user: "Added `mcp-atlassian` to `./.mcp.json`. Restart Claude Code and approve the new MCP server when prompted, then re-run `/jira-ticket`." Stop the run — the tools won't be available until restart.

  6. If the user picks **no**, stop. Do not proceed without the tools.

### Step 1 — Validate credentials

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
  - `JIRA_PERSONAL_TOKEN` → create a Personal Access Token in your Jira profile, then `export JIRA_PERSONAL_TOKEN=<your-pat>`. `JIRA_USERNAME` is optional here, but if you set it the skill will use it for the assignee / reporter on created tickets.

Encourage the user to add the relevant exports to their `~/.zshrc` or `~/.bashrc`.

### Step 2 — Resolve project (auto-discover if needed)

Check `$JIRA_PROJECT_KEY`:
```bash
echo "JIRA_PROJECT_KEY=${JIRA_PROJECT_KEY:-NOT_SET}"
```

If set, use that value as the resolved project key for the rest of the run. If `NOT_SET`:

1. Call `mcp__mcp-atlassian__jira_get_all_projects` to list available projects.
2. Present them to the user as a numbered list of `KEY — Name` (e.g., `1. PROJ — My Project`). If there are many, group/sort sensibly.
3. Ask the user to pick one.
4. Treat the picked key as the resolved `$JIRA_PROJECT_KEY` for the rest of this run.
5. Offer to persist: "Save `JIRA_PROJECT_KEY=<KEY>` to your shell rc so you don't have to pick again next time? (yes/no)"
6. If yes → follow the **Persisting to shell rc** procedure below with `VAR_NAME=JIRA_PROJECT_KEY` and `VAR_VALUE=<picked key>`.

### Step 3 — Resolve board (only if sprint placement requested)

Skip this step entirely unless the user passed `current`, `sprint`, or `next` as a sprint argument.

Check `$JIRA_BOARD_ID`:
```bash
echo "JIRA_BOARD_ID=${JIRA_BOARD_ID:-NOT_SET}"
```

If set, use that value as the resolved board id. If `NOT_SET`:

1. Call `mcp__mcp-atlassian__jira_get_agile_boards` filtered by the resolved project key.
2. Present them to the user as a numbered list of `ID — Name (Type)` (e.g., `1. 6 — Engineering Scrum (scrum)`).
3. Ask the user to pick one.
4. Treat the picked id as the resolved `$JIRA_BOARD_ID` for the rest of this run.
5. Offer to persist: "Save `JIRA_BOARD_ID=<ID>` to your shell rc? (yes/no)"
6. If yes → follow the **Persisting to shell rc** procedure below with `VAR_NAME=JIRA_BOARD_ID` and `VAR_VALUE=<picked id>`.

If the project has no boards, tell the user, leave the issue in the backlog, and skip sprint assignment.

### Persisting to shell rc

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

## Parsing Arguments

`/jira-ticket [args]` — parse the comma-separated arguments to determine the mode.

The Jira issue key pattern in this skill is `${JIRA_PROJECT_KEY}-\d+` (e.g., if `JIRA_PROJECT_KEY=PROJ`, then `PROJ-1234`).

### Mode Detection

- If any **standalone** argument exactly matches the issue key pattern:
  - If `description` is also passed as an argument → enter **Update Description Mode**
  - Otherwise → enter **Comment Mode**
  The entire trimmed argument must be the issue key — ignore keys that appear as part of other arguments (e.g., `epic PROJ-1234` is an epic linking argument, not a comment target).
- Otherwise, enter **Create Mode**

### Create Mode Arguments

`/jira-ticket [issue_type][, sprint][, priority][, epic <keyword>][, label <name>]...`

- **Issue type**: `Bug`, `Story`, `Epic`, `Subtask`. Case-insensitive. If omitted, infer from context. **Always prefer Story over Task.** If ambiguous, ask.
- **Sprint placement**:
  - `current` or `sprint` → current active sprint
  - `next` → next future sprint (query `state: future`, pick earliest)
  - Default → backlog
- **Priority**: `Critical`, `High`, `Medium`, `Low`, `Lowest`. Only set if explicitly provided. Otherwise, let Jira default apply.
- **Epic**: If an argument starts with `epic ` followed by a keyword (e.g., `epic <CustomerName>`, `epic Onboarding`), search for a matching epic to link. The keyword can be a customer name, feature name, or any search term. Can also be inferred from conversation context.
- **Label**: If an argument starts with `label ` followed by a name (e.g., `label production-issue`, `label tech-debt`), add that label to the created ticket. May be repeated to add multiple labels.

Examples:
- `/jira-ticket bug` → Bug, backlog, no epic
- `/jira-ticket story, current` → Story, current sprint, no epic
- `/jira-ticket bug, epic Onboarding` → Bug, backlog, linked to Onboarding epic
- `/jira-ticket story, current, epic Billing` → Story, current sprint, linked to Billing epic
- `/jira-ticket bug, current, critical, epic Auth` → Bug, current sprint, Critical, linked to Auth epic
- `/jira-ticket bug, next` → Bug, next future sprint, no epic
- `/jira-ticket bug, label production-issue` → Bug, backlog, `production-issue` label
- `/jira-ticket bug, current, label production-issue, epic Payments` → Bug, current sprint, `production-issue` label, linked to Payments epic
- `/jira-ticket` → infer type from context, backlog, no epic

### Comment Mode Arguments

`/jira-ticket <ISSUE_KEY>`

The issue key is the target ticket. All other arguments are ignored — no type, sprint, or priority needed.

Examples:
- `/jira-ticket PROJ-1234` → add comment to PROJ-1234

### Update Description Mode Arguments

`/jira-ticket <ISSUE_KEY>, description`

The issue key is the target ticket. The `description` keyword triggers updating the ticket's description instead of adding a comment.

Examples:
- `/jira-ticket PROJ-1234, description` → update description of PROJ-1234

---

## Gathering Content

Before creating or commenting, review the current conversation and gather:

- **Bottom line**: The key takeaway — what the reader needs to know first
- **Code references**: Up to 3 snippets (max 15 lines each). Use `...` to show only relevant parts
- **SQL queries**: If relevant SQL was discussed or written

Then use the appropriate template based on the issue type.

### Bug Template

For Bugs — focused on what's broken, why, and how to fix it.

```
**<Bottom line — one sentence summarizing the key finding>**

## Root Cause Analysis
<What was investigated and why the issue happens. Use Markdown tables to present evidence — specific IDs, values, statuses with ✅/❌ markers for clarity.>

## Reproduction
<URL or steps to reproduce>

## Proposed Fix
<Recommended solution path. Bold the owning module/component. Include the data flow or join path if relevant.>

## Code References
<Up to 3 code snippets with file paths — see formatting rules below>

## Relevant Queries
<SQL queries used in investigation or relevant to the fix>
```

### Story / Feature Template

For Stories, Epics — focused on what to build and how.

```
**<Bottom line — one sentence summarizing what we're building and why>**

## Code References
<Up to 3 code snippets showing relevant existing code — see formatting rules below>

## Relevant Queries
<SQL queries relevant to the feature>
```

### Section Rules

- **Bottom line**: Always first. Bold one-liner.
- **Code References & Relevant Queries**: Optional but **actively look for them** in the conversation. If code was discussed, files were read, or queries were written during the session, include them. They add significant value for the developer picking up the ticket.
- All other sections: Only include if there's content — skip empty sections entirely.

### Code Snippet Formatting

````
**`path/to/file.py:42`**
```python
def process_item(item_id):
    details = fetch_details(item_id)
    ...
    return details.normalize()
```
````

Rules:
- Maximum 3 snippets
- Maximum 15 lines each
- Use `...` to replace irrelevant lines in the middle
- Include file path and line number as a bold header
- Use the appropriate language tag for syntax highlighting

---

## Create Mode

### 1. Draft and Confirm

Present the draft to the user before creating:
- Summary (title, under 80 chars)
- Issue type
- Sprint placement (or "Backlog" if none)
- Epic (or "None" if none)
- Description preview

### 2. Create the Issue

Use `mcp__mcp-atlassian__jira_create_issue` with:
- `project_key`: value of `$JIRA_PROJECT_KEY`
- `summary`: The confirmed title
- `issue_type`: The determined type
- `assignee`: Value of `$JIRA_USERNAME` if set; otherwise omit and let Jira default.
- `description`: The built content
- `additional_fields`: If `$JIRA_USERNAME` is set, include `{"reporter": {"id": "<account_id>"}}` — look up the account ID using `mcp__mcp-atlassian__jira_get_user_profile` with the `$JIRA_USERNAME` value first; if unset (e.g. PAT-only Server/DC users), omit the reporter override. Also include `{"priority": {"name": "<Priority>"}}` only if the user explicitly provided a priority. If any `label <n>` arguments were passed, include `{"labels": [<name>, ...]}` in additional_fields with all collected label names.

### 3. Epic Linking

If an `epic <keyword>` argument was provided, or a topic was mentioned in the conversation that suggests an epic:
1. Search using `mcp__mcp-atlassian__jira_search` with JQL: `issuetype = Epic AND project = $JIRA_PROJECT_KEY AND summary ~ "<keyword>"`
2. If a single matching epic is found, link the ticket to it using `mcp__mcp-atlassian__jira_link_to_epic` or by including `{"epicKey": "<EPIC_KEY>"}` in `additional_fields`
3. If multiple epics match, show them to the user and ask which one to use
4. If no epic is found, inform the user and skip — don't create one

### 4. Sprint Assignment

If sprint was requested, the board id was already resolved in Prerequisites Step 3.

1. Get the board sprints using `mcp__mcp-atlassian__jira_get_sprints_from_board` with the resolved `board_id`
   - For `current`: use `state: active`
   - For `next`: use `state: future`, pick the earliest by start date
2. Add the issue using `mcp__mcp-atlassian__jira_add_issues_to_sprint`

If no matching sprint is found, inform the user and leave in backlog.

### 5. Confirm

Always present the issue link to the user:
- Issue key with link (e.g., `${JIRA_URL}/browse/<ISSUE_KEY>`)
- Issue type, sprint placement, summary
- Epic (if linked)

---

## Comment Mode

### 1. Draft and Confirm

Present the draft comment content to the user before posting:
- Target issue key
- Comment preview

### 2. Add the Comment

Use `mcp__mcp-atlassian__jira_add_comment` with:
- `issue_key`: The provided issue key (e.g., `PROJ-1234`)
- `body`: The built content

### 3. Confirm

Always present the issue link to the user:
- Issue link (e.g., `${JIRA_URL}/browse/<ISSUE_KEY>`)
- Brief summary of what was posted

---

## Update Description Mode

### 1. Fetch Current Description

Use `mcp__mcp-atlassian__jira_get_issue` with `fields: "description"` to read the current description.

### 2. Draft and Confirm

Present the draft updated description to the user before applying:
- Target issue key
- Current description (summarized)
- New description preview

The new description is built from the conversation context using the same content gathering rules. It **replaces** the existing description — if the current description has content worth keeping, merge it into the new version.

### 3. Update the Description

Use `mcp__mcp-atlassian__jira_update_issue` with:
- `issue_key`: The provided issue key
- `fields`: `{"description": "<new description in Markdown>"}`

### 4. Confirm

Always present the issue link to the user:
- Issue link (e.g., `${JIRA_URL}/browse/<ISSUE_KEY>`)
- Brief summary of what was updated
