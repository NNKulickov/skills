#!/usr/bin/env bash
# Rebuild the vendored, fully offline Excalidraw bundle used by render_template.html.
#
# Why vendored: the upstream skill imported @excalidraw/excalidraw from a CDN at
# render time. esm.sh's ?bundle build is currently broken (404 on a transitive
# dep), and any CDN import means the renderer needs network on every run.
#
# Produces:
#   vendor/excalidraw.bundle.js  — self-contained ESM exporting exportToSvg
#   vendor/fonts/                — Excalifont & co, loaded via EXCALIDRAW_ASSET_PATH
#
# Requires: node + npm. Usage:  ./vendor/build-bundle.sh [version]

set -euo pipefail

VERSION="${1:-0.18.1}"
VENDOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building @excalidraw/excalidraw@$VERSION into $VENDOR_DIR"

cd "$BUILD_DIR"
npm init -y >/dev/null
npm i --no-audit --no-fund \
  "@excalidraw/excalidraw@$VERSION" react@19 react-dom@19 esbuild >/dev/null

echo 'export { exportToSvg } from "@excalidraw/excalidraw";' > entry.js

./node_modules/.bin/esbuild entry.js \
  --bundle --format=esm --minify \
  --define:process.env.NODE_ENV='"production"' \
  --loader:.woff2=dataurl --loader:.ttf=dataurl --loader:.css=text \
  --outfile="$VENDOR_DIR/excalidraw.bundle.js"

# Fonts are fetched at runtime from EXCALIDRAW_ASSET_PATH, not inlined.
rm -rf "$VENDOR_DIR/fonts"
cp -R "node_modules/@excalidraw/excalidraw/dist/prod/fonts" "$VENDOR_DIR/fonts"

echo "Done: $(du -sh "$VENDOR_DIR" | cut -f1) in $VENDOR_DIR"
