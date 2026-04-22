#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: update.sh <skill-name>

  <skill-name>  name of the installed skill directory under .claude/skills/

Reads .claude/skills/<skill-name>/.local-skill.stamp and re-fetches the skill
from the recorded repo (always to latest HEAD; --force is implied).
USAGE
  exit 2
}

[[ $# -eq 1 ]] || usage
NAME="$1"

case "$NAME" in
  */*|..|.) echo "error: <skill-name> must be a bare directory name" >&2; exit 2 ;;
esac

DEST_DIR=".claude/skills/${NAME}"
STAMP="${DEST_DIR}/.local-skill.stamp"

if [[ ! -f "$STAMP" ]]; then
  echo "error: no stamp at ${STAMP} (skill wasn't installed via local-skill, or stamp was deleted)" >&2
  exit 1
fi

repo=""
path=""
installed_at=""
# shellcheck disable=SC1090
source "$STAMP"

if [[ -z "$repo" || -z "$path" ]]; then
  echo "error: ${STAMP} is missing repo or path" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "updating ${NAME} from ${repo} (previous install: ${installed_at:-unknown})"
exec bash "${SCRIPT_DIR}/download.sh" "$repo" "$path" --force
