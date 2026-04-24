#!/usr/bin/env bash
# Bootstrap the local-skill skill into ./.claude/skills/local-skill/.
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/kolodkin/devpowers/HEAD/local_skill_install.sh | bash
# Passes --force by default so a re-run refreshes an existing install.
# Extra args (e.g. --dry-run) are forwarded to download.sh.
set -euo pipefail

REPO="kolodkin/devpowers"
SKILL_PATH="skills/local-skill"
REF="${LOCAL_SKILL_REF:-HEAD}"

curl -fsSL "https://raw.githubusercontent.com/${REPO}/${REF}/${SKILL_PATH}/scripts/download.sh" \
  | bash -s -- "$REPO" "$SKILL_PATH" --force "$@"
