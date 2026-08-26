#!/usr/bin/env bash
# PlaceCall — legacy convenience installer for Claude Code.
#
# PREFER THE PLUGIN. It auto-updates from this repo; this script does not:
#   /plugin marketplace add voygr-tech/placecall
#   /plugin install placecall@placecall
#
# This script ONLY copies skills/placecall/SKILL.md into your Claude Code skills dir.
# No network calls, no other side effects — you can also copy the file by hand.
# (Codex users: don't run this — use the Codex skill installer, see README.)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/.claude/skills/placecall"
mkdir -p "$DEST"
cp "$SRC/skills/placecall/SKILL.md" "$DEST/SKILL.md"
echo "✓ Installed: $DEST/SKILL.md"

# This project was called Callwright until 2026-08. A copy installed under the
# old name is still a working phone skill, so leaving it in place gives your
# agent two of them and makes routing between them ambiguous.
stale=()
for old in "${HOME}/.claude/skills/callwright" \
           "${HOME}/.claude/skills/callwright-skill"; do
  [ -e "$old" ] && stale+=("$old")
done
if [ ${#stale[@]} -gt 0 ]; then
  echo
  echo "⚠ Found an older copy of this skill under its previous name:"
  printf '    %s\n' "${stale[@]}"
  echo "  Remove it, or your agent will have two phone skills and may pick either:"
  printf '    rm -rf %q\n' "${stale[@]}"
fi

echo "Next:"
echo "  1) export PLACECALL_API_KEY=<your key>   (free self-serve key: https://api.voygr.tech/checkout)"
echo "  2) start a fresh Claude Code session (skills load at startup)"
echo "  3) ask it to call a number — it uses the skill automatically"
