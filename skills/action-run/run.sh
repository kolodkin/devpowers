#!/bin/bash
#
# GitHub Actions Workflow Runner
# Usage: run.sh <workflow> [key=value|flag ...] [branch=<name>]
#   workflow     — workflow filename or name (e.g. publish.yaml)
#   key=value    — workflow dispatch input
#   flag         — shorthand for flag=true
#   branch=<name> — run from specific branch (default: current git branch)
#
# Example:
#   run.sh publish tag=v1.2.3 pre-release
#   run.sh publish tag=v1.2.3 branch=main
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GH_VERSION="2.62.0"
GH_ARCHIVE="gh_${GH_VERSION}_linux_amd64"

WORKFLOW=""
declare -a INPUT_ARGS=()
RUN_ID=""
REF=""

echo -e "${BLUE}⚡ GitHub Actions Runner${NC}"
echo ""

# ── Parse arguments ──────────────────────────────────────────────────────────

parse_args() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ Usage: $0 <workflow> [key=value|flag ...]${NC}"
        exit 1
    fi

    local input="$1"
    shift

    # Resolve workflow name: append .yaml if no extension, then verify it exists
    if [[ "$input" != *.yaml && "$input" != *.yml ]]; then
        WORKFLOW="${input}.yaml"
    else
        WORKFLOW="$input"
    fi

    REF=$(git branch --show-current 2>/dev/null || echo "")

    for arg in "$@"; do
        if [[ "$arg" == branch=* ]]; then
            REF="${arg#branch=}"
        elif [[ "$arg" == *"="* ]]; then
            INPUT_ARGS+=("-f" "$arg")
        else
            INPUT_ARGS+=("-f" "${arg}=true")
        fi
    done

    echo -e "${BLUE}  Workflow: ${NC}$WORKFLOW"
    echo -e "${BLUE}  Branch:   ${NC}${REF:-(default)}"
    for arg in "${INPUT_ARGS[@]}"; do
        if [ "$arg" != "-f" ]; then
            echo -e "${BLUE}  Input:    ${NC}$arg"
        fi
    done
}

# ── Install gh CLI ────────────────────────────────────────────────────────────

install_gh() {
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}✓ GitHub CLI $(gh --version | head -1)${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠️  Installing GitHub CLI...${NC}"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget -q "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCHIVE}.tar.gz"
        tar -xzf "${GH_ARCHIVE}.tar.gz"
        mkdir -p ~/.local/bin
        mv "${GH_ARCHIVE}/bin/gh" ~/.local/bin/
        rm -rf "${GH_ARCHIVE}"*
        export PATH="$HOME/.local/bin:$PATH"
        echo -e "${GREEN}✓ GitHub CLI installed (~/.local/bin)${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        command -v brew &> /dev/null || { echo -e "${RED}❌ Homebrew required: https://brew.sh${NC}"; exit 1; }
        brew install gh
        echo -e "${GREEN}✓ GitHub CLI installed${NC}"
    else
        echo -e "${RED}❌ Unsupported OS: $OSTYPE${NC}"; exit 1
    fi
}

# ── Check authentication ──────────────────────────────────────────────────────

check_auth() {
    echo ""
    echo -e "${BLUE}Checking authentication...${NC}"
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ Not authenticated. Run: gh auth login${NC}"
        echo "   Or set: export GH_TOKEN=<token>"
        exit 1
    fi
    echo -e "${GREEN}✓ Authenticated${NC}"

}

# ── Detect repository ─────────────────────────────────────────────────────────

detect_repo() {
    echo ""
    echo -e "${BLUE}Detecting repository...${NC}"
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)
    [ -z "$REMOTE_URL" ] && { echo -e "${RED}❌ No git remote found${NC}"; exit 1; }

    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ /git/([^/]+)/([^/.]+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo -e "${RED}❌ Cannot parse repo from: $REMOTE_URL${NC}"; exit 1
    fi

    echo -e "${GREEN}✓ Repository: ${NC}$REPO"
}

# ── Check write permission ────────────────────────────────────────────────────

check_permissions() {
    echo ""
    echo -e "${BLUE}Checking permissions...${NC}"
    AUTH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [ -n "$AUTH_USER" ]; then
        PERM=$(gh api "repos/$REPO/collaborators/$AUTH_USER/permission" \
            --jq '.permission' 2>/dev/null || echo "unknown")
        if [[ "$PERM" == "read" || "$PERM" == "none" ]]; then
            echo -e "${RED}❌ '$AUTH_USER' has '$PERM' access — need write or admin to trigger workflows${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Permission: $PERM ($AUTH_USER)${NC}"
    fi

}

# ── Check for already-running workflow ───────────────────────────────────────

check_running() {
    echo ""
    echo -e "${BLUE}Checking for active runs of '$WORKFLOW'...${NC}"

    ACTIVE=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 5 \
        --json databaseId,status,displayTitle \
        --jq '[.[] | select(.status == "in_progress" or .status == "queued" or .status == "waiting")]' \
        2>/dev/null || echo "[]")

    COUNT=$(echo "$ACTIVE" | jq 'length')
    if [ "$COUNT" -gt 0 ]; then
        RUN_ID=$(echo "$ACTIVE" | jq -r '.[0].databaseId')
        STATUS=$(echo "$ACTIVE" | jq -r '.[0].status')
        TITLE=$(echo "$ACTIVE" | jq -r '.[0].displayTitle')
        echo -e "${YELLOW}⚠️  Active run found — monitoring instead of re-triggering:${NC}"
        echo -e "   Run #$RUN_ID  [$STATUS]  $TITLE"
        return 0
    fi

    echo -e "${GREEN}✓ No active runs${NC}"
    return 1
}

# ── Trigger workflow ──────────────────────────────────────────────────────────

trigger_workflow() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🚀 Triggering: $WORKFLOW${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    REF_ARGS=()
    [ -n "$REF" ] && REF_ARGS+=("--ref" "$REF")

    TRIGGER_OUT=$(mktemp)
    if [ ${#INPUT_ARGS[@]} -gt 0 ]; then
        gh workflow run "$WORKFLOW" --repo "$REPO" "${REF_ARGS[@]}" "${INPUT_ARGS[@]}" 2>"$TRIGGER_OUT" || true
    else
        gh workflow run "$WORKFLOW" --repo "$REPO" "${REF_ARGS[@]}" 2>"$TRIGGER_OUT" || true
    fi
    if [ -s "$TRIGGER_OUT" ]; then
        ERR=$(cat "$TRIGGER_OUT"); rm -f "$TRIGGER_OUT"
        if echo "$ERR" | grep -q "403\|Resource not accessible"; then
            echo -e "${RED}❌ Permission denied (HTTP 403) — token cannot trigger workflow_dispatch events${NC}"
            echo "   For classic PATs:      add 'workflow' scope at github.com/settings/tokens"
            echo "   For fine-grained PATs: enable 'Actions: write' permission"
            echo "   Or re-authenticate:    gh auth login --scopes workflow"
        else
            echo -e "${RED}❌ Failed to trigger workflow:${NC} $ERR"
        fi
        exit 1
    fi
    rm -f "$TRIGGER_OUT"

    echo -e "${GREEN}✓ Workflow triggered${NC}"
    echo ""
    echo -e "${BLUE}⏳ Waiting for run to register...${NC}"
    sleep 6

    for i in 1 2 3 4 5; do
        RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" \
            --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
        [ -n "$RUN_ID" ] && break
        echo -e "${YELLOW}  Attempt $i — waiting...${NC}"
        sleep 5
    done

    [ -z "$RUN_ID" ] && { echo -e "${RED}❌ Could not retrieve run ID${NC}"; exit 1; }
    echo -e "${GREEN}✓ Run ID: $RUN_ID${NC}"
}

# ── Monitor run to completion ─────────────────────────────────────────────────

monitor_run() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⏳ Monitoring run #$RUN_ID${NC}"
    echo -e "${BLUE}   https://github.com/$REPO/actions/runs/$RUN_ID${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    LAST_STATUS=""
    while true; do
        set +e
        DATA=$(gh run view "$RUN_ID" --repo "$REPO" --json status,conclusion,jobs 2>/dev/null)
        set -e
        [ -z "$DATA" ] && { sleep 15; continue; }

        STATUS=$(echo "$DATA" | jq -r '.status')
        CONCLUSION=$(echo "$DATA" | jq -r '.conclusion')

        [ "$STATUS" != "$LAST_STATUS" ] && echo -e "\n${BLUE}Status: ${NC}$STATUS" && LAST_STATUS="$STATUS"
        [ "$STATUS" = "completed" ] && break

        echo "$DATA" | jq -r '.jobs[] | "  [\(.status)\(if .conclusion then "/" + .conclusion else "" end)] \(.name)"' 2>/dev/null || true
        sleep 20
    done

    echo ""
    if [ "$CONCLUSION" = "success" ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ SUCCESS — $WORKFLOW${NC}"
        echo -e "${GREEN}   https://github.com/$REPO/actions/runs/$RUN_ID${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ FAILURE — $WORKFLOW (conclusion: $CONCLUSION)${NC}"
        echo -e "${RED}   https://github.com/$REPO/actions/runs/$RUN_ID${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}📋 Failed job logs:${NC}"
        echo ""
        gh run view "$RUN_ID" --repo "$REPO" --log-failed 2>&1 || true
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}💡 Analyze the errors above, fix the issue, and re-run${NC}"
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"
    echo ""
    install_gh
    check_auth
    detect_repo
    check_permissions

    if check_running; then
        monitor_run
    else
        trigger_workflow
        monitor_run
    fi
}

main "$@"
