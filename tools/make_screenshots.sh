#!/usr/bin/env bash
# Regenerate docs/images/ from the running game.
#
#   tools/make_screenshots.sh [path-to-godot]
#
# The game has a headless-friendly screenshot mode: passing `--shot` makes it
# render three frames and quit. Everything here is reproducible - if you change
# the levels or the UI, re-run this and commit the new images.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Godot is a native Windows binary here; under MSYS/Git-Bash $PWD is a POSIX
# path it cannot open, so hand it a Windows one.
case "$ROOT" in
	[A-Za-z]:*) ;;
	*) ROOT="$(cygpath -m "$ROOT" 2>/dev/null || echo "$ROOT")" ;;
esac
OUT="$ROOT/docs/images"
GODOT="${1:-${GODOT:-godot}}"

mkdir -p "$OUT"
UDIR="$HOME/AppData/Roaming/Godot/app_userdata/InnerBox"

capture() {
	local name="$1"; shift
	echo "  -> $name"
	"$GODOT" --path "$ROOT" --resolution 1024x576 res://src/main.tscn \
		-- --shot "$@" >/dev/null 2>&1
	cp "$UDIR/shot_2.png" "$OUT/$name.png"
}

echo "capturing areas..."
capture 01-hollowmere  --area=village
capture 02-whisperwood --area=woods
capture 03-rust-hollow --area=hollow
capture 04-the-core    --area=core
capture 05-the-loft   --area=attic

echo "capturing interface..."
capture 06-dialogue    --area=village --talk=elder_intro
capture 07-quests      --area=village --menu=quests
capture 08-satchel     --area=village --menu=inventory
capture 09-codex       --area=village --menu=codex
capture 10-pause       --area=village --menu=pause

echo "capturing tile atlas..."
python "$ROOT/tools/gen_assets.py" >/dev/null
cp "$ROOT/tools/preview.png" "$OUT/00-assets.png"

echo "done -> $OUT"
ls -la "$OUT"
