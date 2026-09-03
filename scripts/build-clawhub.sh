#!/usr/bin/env bash
# Build the ClawHub artifact of the skill from the canonical SKILL.md.
#
# One skill text, two listings, two surface markers. The canonical file
# (skills/call/SKILL.md) is what the Claude Code plugin/marketplace,
# install.sh and Codex users get, so it carries the `claude-plugin` surface.
# ClawHub is published by hand from clawhub/placecall/SKILL.md (the folder name
# is the slug the CLI derives, so keep it `placecall`), which is the same text
# with the surface swapped to `clawhub`. The marker is telemetry only (the
# X-Client-Surface header on POST /calls and ?src= on the checkout links); it
# never affects auth, billing or the call - it only tells the backend which
# listing a call came from, and a wrong one attributes ClawHub calls to the
# plugin.
#
#   scripts/build-clawhub.sh          # regenerate clawhub/placecall/SKILL.md
#   scripts/build-clawhub.sh --check  # CI: fail when the artifact is stale
#                                     # or a file carries the wrong surface
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=skills/call/SKILL.md
OUT=clawhub/placecall/SKILL.md
PLUGIN=claude-plugin
CLAWHUB=clawhub

markers() { # markers <surface> <file> -> number of surface markers in the file
  grep -c -E "X-Client-Surface: $1|[?]src=$1" "$2" || true # grep -c exits 1 on zero
}

# The canonical file carries exactly one surface: the plugin's.
if [ "$(markers "$CLAWHUB" "$SRC")" -ne 0 ]; then
  echo "error: $SRC carries '$CLAWHUB' surface markers; the canonical file must say '$PLUGIN' everywhere" >&2
  grep -n -E "X-Client-Surface: $CLAWHUB|[?]src=$CLAWHUB" "$SRC" >&2
  exit 1
fi
src_markers=$(markers "$PLUGIN" "$SRC")
if [ "$src_markers" -eq 0 ]; then
  echo "error: $SRC carries no '$PLUGIN' surface markers - nothing to attribute" >&2
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
sed -e "s/X-Client-Surface: $PLUGIN/X-Client-Surface: $CLAWHUB/g" \
    -e "s/?src=$PLUGIN/?src=$CLAWHUB/g" "$SRC" > "$tmp"

# Every marker was swapped, and no trace of the plugin surface is left.
if [ "$(markers "$CLAWHUB" "$tmp")" -ne "$src_markers" ] || grep -q "$PLUGIN" "$tmp"; then
  echo "error: surface swap incomplete ($src_markers markers in $SRC)" >&2
  grep -n "$PLUGIN" "$tmp" >&2 || true
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  if [ ! -f "$OUT" ] || ! cmp -s "$tmp" "$OUT"; then
    echo "error: $OUT is stale - run scripts/build-clawhub.sh and commit the result" >&2
    [ -f "$OUT" ] && diff -u "$OUT" "$tmp" >&2 || true
    exit 1
  fi
  echo "ok: $OUT is in sync with $SRC ($src_markers surface markers -> $CLAWHUB)"
  exit 0
fi

mkdir -p "$(dirname "$OUT")"
cp "$tmp" "$OUT"
echo "wrote $OUT ($src_markers surface markers -> $CLAWHUB)"
