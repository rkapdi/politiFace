#!/usr/bin/env bash
# Build the web app and sync it into docs/app/ (served by GitHub Pages
# from the branch, same deploy path as the rest of the site).
set -euo pipefail
cd "$(dirname "$0")/.."
npm run build
rm -rf ../docs/app
mkdir -p ../docs/app
cp -R dist/. ../docs/app/
echo "Synced web/dist -> docs/app"
