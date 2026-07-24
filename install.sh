#!/usr/bin/env bash
# Install the callwright skill for Claude Code.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/.claude/skills/callwright-skill"
mkdir -p "$DEST"
cp "$SRC/SKILL.md" "$DEST/SKILL.md"
echo "✓ Installed: $DEST/SKILL.md"
echo "Next:"
echo "  1) export CALLWRIGHT_API_KEY=<your key from the organizers>"
echo "  2) start a fresh Claude Code session (skills load at startup)"
echo "  3) ask it to call a number — it uses the skill automatically"
