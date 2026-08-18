#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PART="${1:-patch}"
REPO="${GITHUB_REPOSITORY:-anjun/QuoteBar}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found; install GitHub CLI" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repository" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree is dirty; commit or stash first" >&2
  git status --short
  exit 1
fi

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(tr -d '[:space:]' < BUILD)"
IFS='.' read -r MA MI PA <<< "$VERSION"
case "$PART" in
  major) MA=$((MA + 1)); MI=0; PA=0 ;;
  minor) MI=$((MI + 1)); PA=0 ;;
  patch) PA=$((PA + 1)) ;;
  *) echo "usage: $0 [patch|minor|major]" >&2; exit 1 ;;
esac
NEW="$MA.$MI.$PA"
NEW_BUILD=$((BUILD + 1))

echo "$NEW" > VERSION
echo "$NEW_BUILD" > BUILD
plutil -replace CFBundleShortVersionString -string "$NEW" Resources/Info.plist
plutil -replace CFBundleVersion -string "$NEW_BUILD" Resources/Info.plist

perl -pi -e "s/return \"[0-9]+\\.[0-9]+\\.[0-9]+\"/return \"$NEW\"/" Sources/QuoteBar/AppVersion.swift

git add VERSION BUILD Resources/Info.plist Sources/QuoteBar/AppVersion.swift
git commit -m "release: v$NEW"
git tag "v$NEW"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "creating private GitHub repo $REPO"
  gh repo create "$REPO" --private --source=. --remote=origin --push
else
  git push -u origin HEAD
fi

git push origin "v$NEW"
gh release create "v$NEW" --repo "$REPO" --title "QuoteBar v$NEW" --generate-notes
echo "Release v$NEW created. CI will attach QuoteBar-$NEW.dmg"
