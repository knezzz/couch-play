#!/usr/bin/env bash
# Builds apps/tv/assets/packs/ from tool/packs/: text packs are copied, folder packs are zipped.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/tool/packs"
out="$root/apps/tv/assets/packs"
mkdir -p "$out"
rm -f "$out"/*.json "$out"/*.zip
cp "$src"/*.json "$out"/
for dir in "$src"/*/; do
  name="$(basename "$dir")"
  (cd "$dir" && zip -qrX "$out/$name.zip" .)
done
ls -l "$out"
