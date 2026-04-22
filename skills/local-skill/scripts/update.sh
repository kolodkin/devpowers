#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: update.sh <skill-name> [--dry-run]

  <skill-name>  name of the installed skill directory under .claude/skills/
  --dry-run     show what update would do without modifying any files

Reads .claude/skills/<skill-name>/.local-skill.stamp and re-fetches the skill
from the recorded repo (always to latest HEAD; --force is implied).
USAGE
  exit 2
}

NAME=""
FORWARD=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) FORWARD+=(--dry-run) ;;
    -h|--help) usage ;;
    *)
      [[ -n "$NAME" ]] && usage
      NAME="$arg"
      ;;
  esac
done

[[ -n "$NAME" ]] || usage

case "$NAME" in
  */*|..|.) echo "error: <skill-name> must be a bare directory name" >&2; exit 2 ;;
esac

STAMP=".claude/skills/${NAME}/.local-skill.stamp"

if [[ ! -f "$STAMP" ]]; then
  echo "error: no stamp at ${STAMP} (skill wasn't installed via local-skill, or stamp was deleted)" >&2
  exit 1
fi

repo=""
path=""
# shellcheck disable=SC1090
source "$STAMP"

if [[ -z "$repo" || -z "$path" ]]; then
  echo "error: ${STAMP} is missing repo or path" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "updating ${NAME} from ${repo}"
exec bash "${SCRIPT_DIR}/download.sh" "$repo" "$path" --force "${FORWARD[@]}"
