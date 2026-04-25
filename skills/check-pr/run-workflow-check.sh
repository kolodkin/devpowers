#!/bin/bash
#
# GitHub Actions Workflow Checker
# Installs gh CLI if needed, polls workflow status, and reports results
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub CLI version for installation
GH_VERSION="2.62.0"
GH_ARCHIVE="gh_${GH_VERSION}_linux_amd64"

echo -e "${BLUE}🔍 GitHub Actions Workflow Checker${NC}"
echo ""

# Step 1: Install gh CLI if not available
install_gh() {
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}✓ GitHub CLI already installed${NC}"
        gh --version
        return 0
    fi

    echo -e "${YELLOW}⚠️  GitHub CLI not found. Installing...${NC}"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing on Linux (local)..."
        wget -q "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCHIVE}.tar.gz"
        tar -xzf "${GH_ARCHIVE}.tar.gz"
        mkdir -p ~/.local/bin
        mv "${GH_ARCHIVE}/bin/gh" ~/.local/bin/
        rm -rf "${GH_ARCHIVE}"*
        export PATH="$HOME/.local/bin:$PATH"
        echo -e "${GREEN}✓ GitHub CLI installed successfully (~/.local/bin)${NC}"
        gh --version

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing on macOS..."
        if command -v brew &> /dev/null; then
            brew install gh
            echo -e "${GREEN}✓ GitHub CLI installed successfully${NC}"
        else
            echo -e "${RED}❌ Error: Homebrew not found${NC}"
            echo "Please install Homebrew first: https://brew.sh"
            exit 1
        fi
    else
        echo -e "${RED}❌ Error: Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
}

# Step 2: Check authentication
check_auth() {
    echo ""
    echo -e "${BLUE}Checking authentication...${NC}"

    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ Not authenticated with GitHub CLI${NC}"
        echo ""
        echo "Please authenticate:"
        echo "  1. Run: gh auth login"
        echo "  2. Or set: export GH_TOKEN=<your-token>"
        exit 1
    fi

    echo -e "${GREEN}✓ Authenticated${NC}"
}

# Step 3: Detect GitHub repository
detect_repo() {
    echo ""
    echo -e "${BLUE}Detecting GitHub repository...${NC}"

    # Try to get repo from git remote
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)

    if [ -z "$REMOTE_URL" ]; then
        echo -e "${RED}❌ Error: No git remote found${NC}"
        exit 1
    fi

    # Extract owner/repo from various remote URL formats
    # Handle: http://*/git/owner/repo, https://github.com/owner/repo, git@github.com:owner/repo
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ /git/([^/]+)/([^/.]+) ]]; then
        # Handle local proxy format: http://local_proxy@127.0.0.1:*/git/owner/repo
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo -e "${RED}❌ Error: Could not parse repository from remote URL: $REMOTE_URL${NC}"
        echo "Please set manually: export GITHUB_REPOSITORY=owner/repo"
        exit 1
    fi

    # Parse owner and repo name
    REPO_OWNER=$(echo "$REPO" | cut -d'/' -f1)
    REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

    echo -e "${GREEN}✓ REPO: ${NC}$REPO"
    echo -e "${GREEN}✓ REPO_OWNER: ${NC}$REPO_OWNER"
    echo -e "${GREEN}✓ REPO_NAME: ${NC}$REPO_NAME"
}

# Step 4: Get current branch
get_branch() {
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$BRANCH" ]; then
        echo -e "${RED}❌ Error: Not a git repository${NC}"
        exit 1
    fi
    echo -e "${BLUE}📝 Branch: ${NC}$BRANCH"
}

# Step 4.5: Check if PR exists for this branch
check_pr_exists() {
    echo ""
    echo -e "${BLUE}Checking for pull request...${NC}"

    # Check if PR exists for this branch
    PR_DATA=$(gh pr list --repo "$REPO" --head "$BRANCH" --json number,state,url 2>/dev/null)

    if [ -z "$PR_DATA" ] || [ "$PR_DATA" = "[]" ]; then
        echo -e "${YELLOW}⚠️  No pull request found for branch '$BRANCH'${NC}"
        echo ""
        echo -e "${YELLOW}ℹ️  Workflow runs only trigger for:${NC}"
        echo "  • Pushes to main/master branches"
        echo "  • Pull requests targeting main/master"
        echo ""
        echo -e "${YELLOW}💡 To trigger CI checks, create a pull request:${NC}"
        echo "  gh pr create --repo $REPO --head $BRANCH --base main --fill"
        echo ""
        echo -e "${YELLOW}Or push to main/master branch (if you have permissions)${NC}"
        echo ""
        return 1
    else
        PR_NUMBER=$(echo "$PR_DATA" | jq -r '.[0].number')
        PR_URL=$(echo "$PR_DATA" | jq -r '.[0].url')
        echo -e "${GREEN}✓ Pull request found: ${NC}#$PR_NUMBER"
        echo -e "${BLUE}  URL: ${NC}$PR_URL"
        return 0
    fi
}

# Step 5: Check for PR review comments
check_review_comments() {
    echo ""
    echo -e "${BLUE}🔍 Checking for unresolved PR review comments...${NC}"
    echo ""

    # Get PR review decision
    REVIEW_DATA=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json reviewDecision 2>/dev/null)

    if [ -z "$REVIEW_DATA" ]; then
        echo -e "${YELLOW}⚠️  Could not fetch PR review data${NC}"
        return 0
    fi

    REVIEW_DECISION=$(echo "$REVIEW_DATA" | jq -r '.reviewDecision')
    echo -e "${BLUE}Review Status: ${NC}$REVIEW_DECISION"

    # Get unresolved review threads using GraphQL API
    UNRESOLVED_THREADS=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              isResolved
              comments(first: 1) {
                nodes {
                  path
                  body
                  line
                }
              }
            }
          }
        }
      }
    }' -f owner="${REPO%/*}" -f repo="${REPO#*/}" -F number="$PR_NUMBER" 2>/dev/null)

    # Count unresolved threads
    UNRESOLVED_COUNT=$(echo "$UNRESOLVED_THREADS" | jq -r '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length' 2>/dev/null || echo "0")

    if [ "$UNRESOLVED_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}📝 PR HAS $UNRESOLVED_COUNT UNRESOLVED REVIEW THREAD(S)${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Get unresolved file paths and lines from GraphQL to filter REST API results
        UNRESOLVED_PATHS=$(echo "$UNRESOLVED_THREADS" | jq -r '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .comments.nodes[0] | {path: .path, line: .line}]' 2>/dev/null)

        # Get comment IDs from REST API, filtered to only unresolved threads
        # Shows the LAST comment body in each thread (most recent concern) while
        # keeping the root comment ID (required for the /replies endpoint).
        ALL_COMMENTS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate 2>/dev/null)
        COMMENTS_WITH_IDS=$(echo "$ALL_COMMENTS" | jq -r --argjson unresolved "$UNRESOLVED_PATHS" '
            . as $all |
            # Find root comments matching unresolved threads
            [ $all[] | select(.in_reply_to_id == null) | select(
                . as $c | any($unresolved[]; .path == $c.path and (.line == $c.line or .line == $c.original_line))
            ) ] |
            .[] | . as $root |
            # Find the last comment in this thread (root + all replies)
            ([ $all[] | select(.id == $root.id or .in_reply_to_id == $root.id) ] | max_by(.id)) as $last |
            "ID: \($root.id)\nFile: \($root.path)\nLine: \($root.line // $root.original_line // "N/A")\nComment: \($last.body)\n---"
        ' 2>/dev/null)

        if [ -n "$COMMENTS_WITH_IDS" ]; then
            echo "$COMMENTS_WITH_IDS"
        else
            # Fallback to GraphQL output without IDs
            echo "$UNRESOLVED_THREADS" | jq -r '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .comments.nodes[0] | "File: \(.path)\nLine: \(.line // "N/A")\nComment: \(.body)\n---"' 2>/dev/null
        fi

        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}💡 See SKILL.md 'Address PR Review Comments' section for reply guidelines${NC}"
        echo ""
    else
        echo -e "${GREEN}✅ No unresolved review comments${NC}"
        echo ""
    fi

    # Check review decision
    if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ]; then
        echo -e "${YELLOW}⚠️  Changes requested by reviewers${NC}"
        echo -e "${YELLOW}Please address all feedback and push changes${NC}"
        echo ""
        return 0
    elif [ "$REVIEW_DECISION" = "APPROVED" ]; then
        echo -e "${GREEN}✅ PR is approved!${NC}"
        echo ""
        return 0
    elif [ "$REVIEW_DECISION" = "REVIEW_REQUIRED" ]; then
        echo -e "${YELLOW}⏳ PR is awaiting review${NC}"
        if [ "$UNRESOLVED_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}But unresolved comments exist - consider addressing them${NC}"
        fi
        echo ""
        return 0
    else
        echo -e "${BLUE}ℹ️  Review status: $REVIEW_DECISION${NC}"
        echo ""
        return 0
    fi
}

# Step 6: Poll PR checks using gh pr checks --watch
poll_checks() {
    echo ""
    echo -e "${BLUE}⏳ Waiting for GitHub to process push...${NC}"
    sleep 3

    # Show initial status
    echo -e "${BLUE}Current check status:${NC}"
    gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null || true
    echo ""

    # Watch until all checks complete
    echo -e "${BLUE}⏳ Watching checks until completion...${NC}"
    set +e
    timeout 1200 gh pr checks "$PR_NUMBER" --repo "$REPO" --watch 2>/dev/null
    WATCH_EXIT=$?
    set -e

    if [ "$WATCH_EXIT" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}STATUS: SUCCESS${NC}"
        echo -e "${GREEN}PR: #$PR_NUMBER${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check for PR review comments after CI passes
        check_review_comments
        exit 0
    fi

    # --watch exited non-zero: could be actual CI failure, pending checks, or review-required status
    # Check if any CI checks actually failed or are still pending
    CHECKS_OUTPUT=$(gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null || true)
    FAILED_CHECKS=$(echo "$CHECKS_OUTPUT" | grep -c "fail" || true)
    PENDING_CHECKS=$(echo "$CHECKS_OUTPUT" | grep -c "pending" || true)

    if [ "$PENDING_CHECKS" -gt 0 ]; then
        # Checks still running - wait for them by polling
        echo ""
        echo -e "${YELLOW}⏳ Checks still pending, polling until complete...${NC}"
        while true; do
            sleep 15
            set +e
            CHECKS_OUTPUT=$(gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null)
            set -e
            PENDING_CHECKS=$(echo "$CHECKS_OUTPUT" | grep -c "pending" || true)
            if [ "$PENDING_CHECKS" -eq 0 ]; then
                break
            fi
            echo -e "${BLUE}  Still waiting on $PENDING_CHECKS pending check(s)...${NC}"
        done
        FAILED_CHECKS=$(echo "$CHECKS_OUTPUT" | grep -c "fail" || true)
    fi

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        # All checks passed - likely review-required status
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}STATUS: ALL CI CHECKS PASSED${NC}"
        echo -e "${GREEN}PR: #$PR_NUMBER${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null || true
        echo ""
        check_review_comments
        exit 0
    fi

    # Actual CI failure - show status and fetch error logs
    echo ""
    echo -e "${RED}❌ Some checks FAILED!${NC}"
    echo ""
    gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null || true
    echo ""

    # Get failed logs
    RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)
    echo -e "${YELLOW}📋 Fetching error logs (run $RUN_ID)...${NC}"
    echo ""

    LOGS=$(gh run view "$RUN_ID" --repo "$REPO" --log-failed 2>&1)

    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}STATUS: FAILURE${NC}"
    echo -e "${RED}PR: #$PR_NUMBER | RUN: $RUN_ID${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "$LOGS"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}💡 Agent should analyze and fix these errors${NC}"
    exit 1
}

# Main execution
main() {
    install_gh
    check_auth
    detect_repo
    get_branch
    check_pr_exists
    if [ "${1:-}" = "--comments-only" ]; then
        check_review_comments
    else
        poll_checks
    fi
}

main "$@"
