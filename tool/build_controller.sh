#!/usr/bin/env bash
# Builds the phone controller and zips it into the TV app's assets.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/apps/tv/assets/controller.zip"

cd "$root/apps/controller"
flutter build web --release --no-web-resources-cdn

mkdir -p "$(dirname "$out")"
rm -f "$out"
cd build/web
zip -qr "$out" .
echo "Wrote $out"
