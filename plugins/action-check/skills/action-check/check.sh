#!/bin/bash
#
# GitHub Actions Workflow Checker
# Usage: check.sh <workflow>
#   workflow — workflow filename (e.g. publish.yaml)
#
# Finds the latest run of the workflow, reports status, and prints
# failed logs if the run failed or is currently failing.
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

echo -e "${BLUE}🔍 GitHub Actions Workflow Checker${NC}"
echo ""

# ── Parse arguments ───────────────────────────────────────────────────────────

parse_args() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ Usage: $0 <workflow>${NC}"
        exit 1
    fi
    WORKFLOW="$1"
    echo -e "${BLUE}  Workflow: ${NC}$WORKFLOW"
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

# ── Check read permission ─────────────────────────────────────────────────────

check_permissions() {
    echo ""
    echo -e "${BLUE}Checking permissions...${NC}"
    AUTH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [ -n "$AUTH_USER" ]; then
        PERM=$(gh api "repos/$REPO/collaborators/$AUTH_USER/permission" \
            --jq '.permission' 2>/dev/null || echo "unknown")
        if [[ "$PERM" == "none" ]]; then
            echo -e "${RED}❌ '$AUTH_USER' has no access to this repository${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Permission: $PERM ($AUTH_USER)${NC}"
    fi
}

# ── Find latest run ───────────────────────────────────────────────────────────

find_latest_run() {
    echo ""
    echo -e "${BLUE}Fetching latest run of '$WORKFLOW'...${NC}"

    RUN_DATA=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 1 \
        --json databaseId,status,conclusion,displayTitle,createdAt,headBranch \
        2>/dev/null || echo "[]")

    if [ "$RUN_DATA" = "[]" ] || [ -z "$RUN_DATA" ]; then
        echo -e "${YELLOW}⚠️  No runs found for workflow '$WORKFLOW'${NC}"
        exit 0
    fi

    RUN_ID=$(echo "$RUN_DATA" | jq -r '.[0].databaseId')
    STATUS=$(echo "$RUN_DATA" | jq -r '.[0].status')
    CONCLUSION=$(echo "$RUN_DATA" | jq -r '.[0].conclusion')
    TITLE=$(echo "$RUN_DATA" | jq -r '.[0].displayTitle')
    BRANCH=$(echo "$RUN_DATA" | jq -r '.[0].headBranch')
    CREATED=$(echo "$RUN_DATA" | jq -r '.[0].createdAt')

    echo -e "${BLUE}  Run #$RUN_ID${NC}"
    echo -e "${BLUE}  Title:   ${NC}$TITLE"
    echo -e "${BLUE}  Branch:  ${NC}$BRANCH"
    echo -e "${BLUE}  Created: ${NC}$CREATED"
    echo -e "${BLUE}  Status:  ${NC}$STATUS / ${CONCLUSION:-running}"
    echo -e "${BLUE}  URL:     ${NC}https://github.com/$REPO/actions/runs/$RUN_ID"
}

# ── Monitor in-progress run ───────────────────────────────────────────────────

monitor_run() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⏳ Run is in progress — monitoring...${NC}"
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
}

# ── Report result ─────────────────────────────────────────────────────────────

report_result() {
    echo ""
    if [ "$CONCLUSION" = "success" ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ SUCCESS — $WORKFLOW${NC}"
        echo -e "${GREEN}   Run #$RUN_ID | https://github.com/$REPO/actions/runs/$RUN_ID${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ FAILURE — $WORKFLOW (conclusion: $CONCLUSION)${NC}"
        echo -e "${RED}   Run #$RUN_ID | https://github.com/$REPO/actions/runs/$RUN_ID${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}📋 Failed job logs:${NC}"
        echo ""
        gh run view "$RUN_ID" --repo "$REPO" --log-failed 2>&1 || true
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}💡 Analyze the errors above, fix the issue, and re-run /action-run${NC}"
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
    find_latest_run

    if [ "$STATUS" != "completed" ]; then
        monitor_run
    fi

    report_result
}

main "$@"
