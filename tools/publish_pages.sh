#!/usr/bin/env bash
# Builds the BlueHaven website - the home page (web/index.html) plus the installable
# game at /play/ - and publishes it to the gh-pages branch, which GitHub Pages serves
# at https://detronics-apps.github.io/<repo>/.
# Run from anywhere:  bash tools/publish_pages.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/Eamon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
SITE=build/site
PAGES=build/gh-pages

# 1. Build the site.
rm -rf "$SITE"
mkdir -p "$SITE/play"
"$GODOT" --headless --path . --export-release "Web Pages" "$SITE/play/index.html"
rm -f "$SITE"/play/*.import
cp web/index.html web/screenshot.png "$SITE/"
cp assets/ui/app_icon_32.png "$SITE/icon_32.png"
cp assets/ui/app_icon_180.png "$SITE/icon_180.png"
touch "$SITE/.nojekyll"  # serve files as they are
echo "* -text" > "$SITE/.gitattributes"  # store every file byte-for-byte

# 2. Check out gh-pages next to the project (first time: create it empty).
if [ ! -d "$PAGES" ]; then
  if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
    git fetch -q origin gh-pages
    git worktree add -B gh-pages "$PAGES" origin/gh-pages
  else
    git worktree add --detach "$PAGES"
    git -C "$PAGES" checkout -q --orphan gh-pages
    git -C "$PAGES" rm -rq --cached . || true
  fi
fi

# 3. Replace its contents with the new site, commit and push.
find "$PAGES" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$SITE"/. "$PAGES"/
git -C "$PAGES" add -A
if git -C "$PAGES" diff --cached --quiet; then
  echo "Site unchanged; nothing to publish."
else
  git -C "$PAGES" commit -q -m "Publish site from $(git rev-parse --short HEAD)"
  git -C "$PAGES" push -q origin gh-pages
  echo "Published."
fi
