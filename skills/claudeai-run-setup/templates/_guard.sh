#!/usr/bin/env bash
# Sourced by every claudeai/*.sh script. These scripts install and run local
# backing services inside the Claude Code web (cloud) container, where they are
# root and own the whole machine. Refuse to run anywhere else unless the caller
# opts in with CLAUDEAI_ALLOW_LOCAL=1.
#
# CLAUDE_CODE_REMOTE=true is set only in the web container. (CLAUDECODE=1 is set
# for every Claude Code session, local included, so it is not a usable gate.)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] && [ "${CLAUDEAI_ALLOW_LOCAL:-}" != "1" ]; then
  printf '\033[31m[claudeai] error:\033[0m %s\n' \
    "not the Claude Code web environment (CLAUDE_CODE_REMOTE != true); set CLAUDEAI_ALLOW_LOCAL=1 to run locally" >&2
  exit 1
fi
