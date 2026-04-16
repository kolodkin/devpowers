#!/bin/bash
#
# skill-zip — build a claude.ai-ready skill zip from a GitHub repo or local dir.
#
# Usage:
#   pack.sh <repo-or-path> [--path <subdir>] [--ref <ref>] [--out <dir>] [--all]
#
# Accepted sources:
#   - owner/repo
#   - https://github.com/owner/repo[.git]
#   - https://github.com/owner/repo/tree/<ref>/<path>
#   - https://github.com/owner/repo/blob/<ref>/<path>/SKILL.md
#   - local directory
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO=""
SUBPATH=""
REF=""
OUT_DIR="$PWD"
ALL=false

echo -e "${BLUE}📦 skill-zip${NC}"
echo ""

# ── Parse arguments ──────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --path) SUBPATH="$2"; shift 2 ;;
        --ref)  REF="$2"; shift 2 ;;
        --out)  OUT_DIR="$2"; shift 2 ;;
        --all)  ALL=true; shift ;;
        -h|--help)
            sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) echo -e "${RED}❌ Unknown flag: $1${NC}"; exit 1 ;;
        *)
            if [ -z "$REPO" ]; then REPO="$1"
            else echo -e "${RED}❌ Unexpected argument: $1${NC}"; exit 1
            fi
            shift ;;
    esac
done

if [ -z "$REPO" ]; then
    echo -e "${RED}❌ Usage: $0 <repo-or-path> [--path <sub>] [--ref <ref>] [--out <dir>] [--all]${NC}"
    exit 1
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

# ── Resolve source ───────────────────────────────────────────────────────────

SOURCE_DIR=""
TMPDIR=""
cleanup() { [ -n "$TMPDIR" ] && rm -rf "$TMPDIR"; return 0; }
trap cleanup EXIT

resolve_source() {
    # Local directory?
    if [ -d "$REPO" ]; then
        SOURCE_DIR="$(cd "$REPO" && pwd)"
        echo -e "${GREEN}✓ Local source: ${NC}$SOURCE_DIR"
        return
    fi

    local url="$REPO"

    # github.com/owner/repo/(tree|blob)/<ref>/<path> → split
    if [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/]+)/(tree|blob)/([^/]+)/(.*)$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]%.git}"
        local kind="${BASH_REMATCH[3]}"
        local ref_from_url="${BASH_REMATCH[4]}"
        local path_from_url="${BASH_REMATCH[5]}"
        url="https://github.com/${owner}/${repo}.git"
        [ -z "$REF" ] && REF="$ref_from_url"
        if [ -z "$SUBPATH" ]; then
            # if blob url pointing to SKILL.md, strip the filename
            if [ "$kind" = "blob" ]; then
                SUBPATH="$(dirname "$path_from_url")"
                [ "$SUBPATH" = "." ] && SUBPATH=""
            else
                SUBPATH="$path_from_url"
            fi
        fi
    elif [[ "$url" =~ ^https?://github\.com/([^/]+)/([^/]+?)(\.git)?/?$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]%.git}"
        url="https://github.com/${owner}/${repo}.git"
    elif [[ "$url" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
        url="https://github.com/${url}.git"
    elif [[ ! "$url" =~ ^https?:// ]] && [[ ! "$url" =~ ^git@ ]]; then
        echo -e "${RED}❌ Not a directory, owner/repo slug, or URL: $REPO${NC}"
        exit 1
    fi

    command -v git >/dev/null || { echo -e "${RED}❌ git is required${NC}"; exit 1; }

    TMPDIR=$(mktemp -d)
    SOURCE_DIR="$TMPDIR/repo"
    echo -e "${BLUE}Cloning ${url}${REF:+ @ $REF}…${NC}"
    local args=(--depth 1 --quiet)
    [ -n "$REF" ] && args+=(--branch "$REF")
    if ! git clone "${args[@]}" "$url" "$SOURCE_DIR" 2>/dev/null; then
        # fallback: full clone then checkout (covers commit SHAs)
        rm -rf "$SOURCE_DIR"
        git clone --quiet "$url" "$SOURCE_DIR"
        if [ -n "$REF" ]; then
            (cd "$SOURCE_DIR" && git checkout --quiet "$REF")
        fi
    fi
    echo -e "${GREEN}✓ Cloned to ${NC}$SOURCE_DIR"
}

resolve_source

# ── Find SKILL.md ────────────────────────────────────────────────────────────

SCAN_DIR="$SOURCE_DIR"
if [ -n "$SUBPATH" ]; then
    SCAN_DIR="$SOURCE_DIR/$SUBPATH"
    if [ ! -d "$SCAN_DIR" ]; then
        echo -e "${RED}❌ --path not found in source: $SUBPATH${NC}"; exit 1
    fi
fi

mapfile -t SKILL_FILES < <(find "$SCAN_DIR" \
    \( -name .git -o -name node_modules -o -name __pycache__ -o -name .venv -o -name venv \) -prune -o \
    -name SKILL.md -print 2>/dev/null | sort)

if [ ${#SKILL_FILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ No SKILL.md found under ${SCAN_DIR#$SOURCE_DIR/}${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Found ${#SKILL_FILES[@]} skill(s):${NC}"
for f in "${SKILL_FILES[@]}"; do
    echo "  ${f#$SOURCE_DIR/}"
done

if [ ${#SKILL_FILES[@]} -gt 1 ] && [ "$ALL" != "true" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Multiple skills found. Re-run with --all, or narrow via --path <subdir>.${NC}"
    exit 1
fi

# ── Parse frontmatter + pack each skill ──────────────────────────────────────

command -v python3 >/dev/null || { echo -e "${RED}❌ python3 is required (for YAML frontmatter parsing)${NC}"; exit 1; }
command -v zip     >/dev/null || { echo -e "${RED}❌ 'zip' is required (apt install zip / brew install zip)${NC}"; exit 1; }

MAX_BYTES=$((30 * 1024 * 1024))
declare -a PRODUCED=()

pack_skill() {
    local skill_file="$1"
    local skill_dir; skill_dir="$(dirname "$skill_file")"

    # Extract name + description length from frontmatter.
    local meta
    meta=$(python3 - "$skill_file" <<'PY'
import sys, re
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    txt = f.read()
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', txt, re.DOTALL)
if not m:
    sys.exit("Missing YAML frontmatter")
lines = m.group(1).split("\n")
fields = {}
i = 0
while i < len(lines):
    km = re.match(r'^([A-Za-z0-9_-]+):\s*(.*)$', lines[i])
    if km:
        key = km.group(1)
        val = km.group(2)
        j = i + 1
        while j < len(lines) and re.match(r'^\s+\S', lines[j]):
            val += " " + lines[j].strip()
            j += 1
        fields[key] = val.strip().strip('"').strip("'")
        i = j
    else:
        i += 1
name = fields.get("name")
desc = fields.get("description")
if not name: sys.exit("frontmatter missing 'name'")
if not desc: sys.exit("frontmatter missing 'description'")
print(f"NAME={name}")
print(f"DESC_LEN={len(desc)}")
PY
    ) || { echo -e "${RED}❌ Frontmatter error in ${skill_file#$SOURCE_DIR/}: $meta${NC}"; return 1; }

    local NAME DESC_LEN
    eval "$meta"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Packing: ${skill_dir#$SOURCE_DIR/}${NC}"
    echo -e "${BLUE}  name: ${NC}$NAME"
    echo -e "${BLUE}  description length: ${NC}$DESC_LEN chars"

    if [[ ! "$NAME" =~ ^[a-z0-9-]{1,64}$ ]]; then
        echo -e "${RED}❌ Invalid name '$NAME' — need ≤64 chars, lowercase/digits/hyphens only${NC}"; return 1
    fi
    if [[ "$NAME" == *anthropic* || "$NAME" == *claude* ]]; then
        echo -e "${RED}❌ Name '$NAME' cannot contain 'anthropic' or 'claude'${NC}"; return 1
    fi
    if [ "$DESC_LEN" -gt 1024 ]; then
        echo -e "${RED}❌ Description is $DESC_LEN chars (>1024 limit)${NC}"; return 1
    fi

    local stage; stage=$(mktemp -d)
    cp -R "$skill_dir/" "$stage/$NAME"
    rm -rf "$stage/$NAME/.git" "$stage/$NAME/.DS_Store" 2>/dev/null || true

    local zip_path="$OUT_DIR/$NAME.zip"
    rm -f "$zip_path"
    (cd "$stage" && zip -qr "$zip_path" "$NAME" -x '*/.git/*' '*/.DS_Store' '*/__pycache__/*' '*/.venv/*')
    rm -rf "$stage"

    local size
    size=$(wc -c < "$zip_path" | tr -d ' ')
    if [ "$size" -gt "$MAX_BYTES" ]; then
        echo -e "${RED}❌ $zip_path is $((size/1024/1024)) MB (>30 MB limit)${NC}"
        rm -f "$zip_path"
        return 1
    fi

    echo -e "${GREEN}✓ $zip_path${NC} ($((size/1024)) KB)"
    PRODUCED+=("$zip_path")
    return 0
}

FAILED=0
for sf in "${SKILL_FILES[@]}"; do
    pack_skill "$sf" || FAILED=$((FAILED + 1))
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ ${#PRODUCED[@]} -eq 0 ]; then
    echo -e "${RED}❌ No zips produced${NC}"
    exit 1
fi

echo -e "${GREEN}Produced ${#PRODUCED[@]} zip(s):${NC}"
for z in "${PRODUCED[@]}"; do echo "  $z"; done
if [ "$FAILED" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $FAILED skill(s) failed — see errors above${NC}"
fi

cat <<EOF

Next steps (manual upload):
  1. Open https://claude.ai/settings/capabilities → Skills
  2. Click "Upload Skill"
  3. Select the zip(s) listed above and toggle each on
  4. Prereqs: Pro/Max/Team/Enterprise plan; enable Capabilities →
     "Code Execution and File Creation" and "Skills"
EOF

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
