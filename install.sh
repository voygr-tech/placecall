#!/usr/bin/env bash
# Claude Code convenience installer.
# It ONLY copies skills/callwright/SKILL.md into your Claude Code skills dir.
# No network calls, no other side effects — you can also copy the file by hand.
# (Codex users: don't run this — use the Codex skill installer, see README.)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/.claude/skills/callwright"
mkdir -p "$DEST"
cp "$SRC/skills/callwright/SKILL.md" "$DEST/SKILL.md"
echo "✓ Installed: $DEST/SKILL.md"
echo "Next:"
echo "  1) export CALLWRIGHT_API_KEY=<your key from the organizers>   (needed to place calls)"
echo "  2) start a fresh Claude Code session (skills load at startup)"
echo "  3) ask it to call a number — it uses the skill automatically"
