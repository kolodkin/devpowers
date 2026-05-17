---
name: setup-mcp
description: >
  Register a known MCP server in this project or in the user's Claude
  Code config. Bounded to the curated list in ./mcps.json — will not
  install MCPs that aren't in the manifest. Use when the user wants to
  install, add, configure, or register an MCP server (e.g. "/setup-mcp",
  "/setup-mcp github", "set up the atlassian mcp", "install
  mcp-atlassian"). Also invoked by other skills when their required MCP
  isn't available in the session.
---

# Setup MCP

Register one of the MCP servers listed in `./mcps.json` into either the project's `.mcp.json`, the user's Claude Code config, or via a manual file edit. The skill is bounded — it will not install MCPs outside the manifest. To add a new server, append an entry to `mcps.json` first (see "Adding a new MCP" below).

## Invocation

```
/setup-mcp                # list known MCPs, prompt to pick one
/setup-mcp <name>         # set up the named MCP
```

## Flow

### 1. Resolve which MCP

Read `./mcps.json`. It maps each `<name>` to its config template, prerequisites, detection tool, and source URL.

- No argument → present a numbered list of `<name> — description` and ask the user to pick.
- `<name>` in the manifest → use that entry.
- `<name>` not in the manifest → tell the user: "`<name>` isn't in the bounded list. Append an entry to `skills/setup-mcp/mcps.json` first, then re-run." Show them an existing entry as a template. Stop — do not search the web for install instructions.

### 2. Detect whether it's already configured

Two checks:

- Is the entry's `detection_tool` (e.g. `mcp__github__list_pull_requests`) visible in your tool list right now?
- Is `<name>` already registered? Try `claude mcp list 2>/dev/null` and grep for it; also check `./.mcp.json` (if it exists) for `mcpServers.<name>`.

If already configured, report where it's registered and stop. Don't reconfigure unless the user explicitly asks ("force", "reconfigure", "overwrite").

### 3. Verify prerequisites

For each command in the entry's `required_cli`, run `command -v <cmd> >/dev/null && echo OK || echo MISSING`. If anything is missing, surface the entry's `notes` (which should explain how to install it) and stop. Don't write any config until prerequisites are in place.

### 4. Show the proposed config

Print the exact JSON snippet that would be added under `mcpServers.<name>` — i.e. the entry's `config_template` verbatim. Also list any `required_env` and `auth_alternatives` so the user knows which env vars / tokens need to be set in their shell.

`${VAR}` expansion inside MCP `env` blocks is unreliable across Claude Code versions — don't depend on it. Env vars should be inherited from the shell that launched Claude Code, or passed through with `-e VAR` for Docker-based servers.

### 5. Ask for scope

Use `AskUserQuestion` with these three options:

- **Project (`./.mcp.json`, shared)** — `claude mcp add --scope project ...`. Checked into the repo so teammates get the same MCP. Use this for MCPs the whole project needs.
- **User (personal, all projects)** — `claude mcp add --scope user ...`. Lives in your Claude Code user config; applies to every project on this machine. Not shared.
- **Manual `./.mcp.json` edit** — Read the file, merge in the entry, write it back. Use this when the `claude mcp` CLI isn't available, or when you want to review the file diff before applying.

### 6. Apply

**Project or User scope** — build a `claude mcp add` invocation from the entry:

- **stdio server** (`config_template` has `command` + `args`):
  ```bash
  claude mcp add --scope <scope> <name> <command> -- <args...>
  ```
  Use `--` to separate the MCP command's args from Claude's own flags. Add `--env KEY=value` only if the entry's `config_template.env` block specifies values (most entries don't — env vars are inherited from the launching shell).

- **HTTP/SSE server** (`config_template` has `type: http` or `type: sse` and `url`):
  ```bash
  claude mcp add --scope <scope> --transport <http|sse> <name> <url>
  ```
  Pass headers via `--header "Name: value"` if the entry specifies them.

Run the command, then verify with `claude mcp list`.

**Manual scope** — operate on `./.mcp.json`:

1. Read the file if it exists; if not, start from `{"mcpServers": {}}`.
2. Parse, set `mcpServers[<name>] = entry.config_template`, write back with 2-space indent + trailing newline.
3. If `mcpServers[<name>]` already exists with a different value, ask before overwriting. Don't clobber other servers or other top-level keys.

### 7. Note env vars

If the entry has `required_env` or `auth_alternatives`, list them with `export KEY=...` examples and (where applicable) the URL to obtain a token. Encourage the user to add the exports to their shell rc (`~/.zshrc` / `~/.bashrc`) so they survive new shells. Do NOT edit the shell rc here — that's the user's call and out of this skill's scope.

### 8. Prompt restart

End with: "Restart Claude Code (or run `/mcp`) so the new server registers. Then re-run whatever skill needed it." Mid-session MCP registrations are not picked up — do not try to use the new server in the current session.

## Adding a new MCP to the manifest

Append an entry to `mcps.json` with this shape:

```json
{
  "<name>": {
    "description": "one-line summary",
    "source": "https://github.com/owner/repo",
    "config_template": { "...": "the mcpServers[<name>] value" },
    "required_cli": ["uvx"],
    "required_env": ["FOO_URL"],
    "auth_alternatives": [["FOO_USER", "FOO_TOKEN"], ["FOO_PAT"]],
    "detection_tool": "mcp__<name>__<some_tool>",
    "notes": "Docker / pipx alternatives, token scopes, anything the user should know."
  }
}
```

Only `description`, `source`, and `config_template` are required. The rest tighten the flow but aren't mandatory. Keep entries to MCPs you've actually used — the value of the bounded list is curation.
