#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: download.sh <repo> <skill-name> [--force]

  <repo>        owner/repo or https://github.com/owner/repo(.git)
  <skill-name>  path to the skill directory within the repo
  --force       overwrite an existing destination directory
USAGE
  exit 2
}

FORCE=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) usage ;;
    *) ARGS+=("$arg") ;;
  esac
done

[[ ${#ARGS[@]} -eq 2 ]] || usage

REPO="${ARGS[0]}"
SKILL_PATH="${ARGS[1]}"

case "$REPO" in
  https://github.com/*|http://github.com/*|git@github.com:*|ssh://git@github.com/*)
    REPO_URL="$REPO"
    ;;
  */*)
    REPO_URL="https://github.com/${REPO%.git}.git"
    ;;
  *)
    echo "error: <repo> must be owner/repo or a github URL" >&2
    exit 2
    ;;
esac

SKILL_PATH="${SKILL_PATH#/}"
SKILL_PATH="${SKILL_PATH%/}"
[[ -n "$SKILL_PATH" ]] || { echo "error: <skill-name> cannot be empty" >&2; exit 2; }

case "$SKILL_PATH" in
  *..*) echo "error: <skill-name> must not contain '..'" >&2; exit 2 ;;
esac

command -v git >/dev/null 2>&1 || { echo "error: git is required but not found on PATH" >&2; exit 127; }

DEST_NAME="$(basename "$SKILL_PATH")"
DEST_DIR=".claude/skills/${DEST_NAME}"

if [[ -e "$DEST_DIR" ]]; then
  if [[ $FORCE -eq 1 ]]; then
    rm -rf "$DEST_DIR"
  else
    echo "error: ${DEST_DIR} already exists (pass --force to overwrite)" >&2
    exit 1
  fi
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" "$TMP_DIR" >/dev/null 2>&1; then
  echo "error: failed to clone ${REPO_URL}" >&2
  exit 1
fi

if ! git -C "$TMP_DIR" sparse-checkout set "$SKILL_PATH" >/dev/null 2>&1; then
  echo "error: sparse-checkout failed for '${SKILL_PATH}'" >&2
  exit 1
fi

SRC="${TMP_DIR}/${SKILL_PATH}"
if [[ ! -d "$SRC" ]]; then
  echo "error: path '${SKILL_PATH}' not found in ${REPO_URL}" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST_DIR")"
cp -R "$SRC" "$DEST_DIR"

echo "installed ${SKILL_PATH} from ${REPO_URL} -> ${DEST_DIR}"
