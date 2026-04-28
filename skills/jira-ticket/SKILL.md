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
  Requires the jira-setup skill to have been run first; if env vars are missing
  this skill will invoke jira-setup automatically.
---

# Jira Ticket — Create or Comment

Two modes, one content engine. The presence of a Jira issue key in the arguments determines the mode.

## Validate env vars

Before parsing arguments or doing any Jira work, run this exact command to check the environment:

```bash
echo "JIRA_URL=${JIRA_URL:-NOT_SET}" && \
echo "JIRA_USERNAME=${JIRA_USERNAME:-NOT_SET}" && \
echo "JIRA_API_TOKEN=${JIRA_API_TOKEN:+SET}" && \
echo "JIRA_PERSONAL_TOKEN=${JIRA_PERSONAL_TOKEN:+SET}" && \
echo "JIRA_PROJECT_KEY=${JIRA_PROJECT_KEY:-NOT_SET}" && \
echo "JIRA_BOARD_ID=${JIRA_BOARD_ID:-NOT_SET}"
```

Required for any run:
- `JIRA_URL` is set
- Auth is set: **either** `JIRA_USERNAME` + `JIRA_API_TOKEN` (Cloud) **or** `JIRA_PERSONAL_TOKEN` (Server / Data Center)
- `JIRA_PROJECT_KEY` is set
- The `mcp__mcp-atlassian__jira_create_issue` tool is visible in your tool list (i.e. the MCP server is registered)

Required only if the user passed a sprint argument (`current`, `sprint`, `next`):
- `JIRA_BOARD_ID` is set

If anything required is missing, tell the user one line — "Jira isn't fully configured; running `/jira-setup` to fix what's missing." — then **invoke the `jira-setup` skill via the Skill tool**. After setup completes, re-run this validation. Only proceed once everything required is green.

If the `jira-setup` skill isn't available in this session for any reason, fall back to instructing the user: "Run `/jira-setup` and then re-run `/jira-ticket`."

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

If sprint was requested, the env-var validation already confirmed `$JIRA_BOARD_ID` is set.

1. Get the board sprints using `mcp__mcp-atlassian__jira_get_sprints_from_board` with `board_id=$JIRA_BOARD_ID`
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
