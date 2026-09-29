#!/bin/sh
set -eu
# Publish the site/ directory to the gh-pages branch (GitHub Pages root).
# Idempotent: no-op when site/ already matches the branch. Safe to run from any
# branch; uses a throwaway worktree so the working tree is never touched.
cd "$(dirname "$0")/.."
branch="${PAGES_BRANCH:-gh-pages}"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/tomatobar-pages.XXXXXX")
cleanup() { git worktree remove --force "$tmp" 2>/dev/null || rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

git fetch -q origin "$branch" 2>/dev/null || true
if git rev-parse -q --verify "origin/$branch" >/dev/null; then
  git worktree add -q --detach "$tmp" "origin/$branch"
  find "$tmp" -mindepth 1 -maxdepth 1 -not -name .git -exec rm -rf {} +
else
  git worktree add -q --detach "$tmp" "$(git hash-object -t tree /dev/null)"
fi
cp -R site/. "$tmp"/
git -C "$tmp" add -A
if git -C "$tmp" diff --cached --quiet; then
  echo "gh-pages already matches site/; nothing to publish"
  exit 0
fi
git -C "$tmp" commit -qm "Publish site from $(git rev-parse --short HEAD)"
git -C "$tmp" push -q origin "HEAD:refs/heads/$branch"
echo "published site/ to https://mikilolipop.github.io/TomatoBar-Personal/"
