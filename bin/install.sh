#!/usr/bin/env bash
# ============================================================================
# autonomous-agent-nightshift installer
# ============================================================================
# Installs as a Claude Code skill.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/noluyorAbi/autonomous-agent-nightshift/main/bin/install.sh | bash
#
#   Or with options:
#   curl -fsSL ... | bash -s -- --project    # install in current project
#   curl -fsSL ... | bash -s -- --user       # install for user (default)
# ============================================================================

set -euo pipefail

REPO_URL="https://github.com/noluyorAbi/autonomous-agent-nightshift"
SKILL_NAME="autonomous-agent-nightshift"
MODE="user"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) MODE="project"; shift ;;
        --user)    MODE="user"; shift ;;
        --help|-h)
            echo "Usage: $0 [--user|--project]"
            echo "  --user     Install to ~/.claude/skills/ (default)"
            echo "  --project  Install to ./.claude/skills/"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ "$MODE" = "user" ]; then
    TARGET="$HOME/.claude/skills/$SKILL_NAME"
else
    TARGET="$PWD/.claude/skills/$SKILL_NAME"
fi

echo "Installing $SKILL_NAME to $TARGET..."

if [ -d "$TARGET" ]; then
    echo "Already installed. Pulling latest..."
    git -C "$TARGET" pull --ff-only
else
    mkdir -p "$(dirname "$TARGET")"
    git clone --depth=1 "$REPO_URL" "$TARGET"
fi

echo ""
echo "✓ Installed to $TARGET"
echo ""
echo "Restart Claude Code, then try:"
echo "  /nightshift-setup"
echo "  /nightshift-review"
echo "  /nightshift-bulletproof"
echo "  /nightshift-status"
echo ""
echo "Or in natural language:"
echo "  \"Set up a nightshift to build {feature}.\""
echo "  \"Review last night's nightshift.\""
echo ""
echo "Docs: $REPO_URL"
