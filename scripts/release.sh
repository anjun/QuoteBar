#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PART="${1:-patch}"
REPO="${GITHUB_REPOSITORY:-anjun/QuoteBar}"

OWNER_LOGIN="anjun"
OWNER_REPO="anjun/QuoteBar"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found; install GitHub CLI" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repository" >&2
  exit 1
fi

login="$(gh api user --jq .login)"
if [[ "$login" != "$OWNER_LOGIN" ]]; then
  echo "make public 仅限 @${OWNER_LOGIN} 使用，当前 GitHub 用户是 ${login}" >&2
  exit 1
fi

if [[ "$REPO" != "$OWNER_REPO" ]]; then
  echo "make public 只发布到 ${OWNER_REPO}，拒绝 ${REPO}" >&2
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
PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

commit_pending_work() {
  if [[ -z "$(git status --porcelain)" ]]; then
    return
  fi
  local pending
  pending="$(git status --short | sed 's/^/- /')"
  git add -A
  git commit -m "$(cat <<EOF
chore: snapshot before v${NEW}

${pending}
EOF
)"
}

write_notes() {
  local notes="$1"
  {
    echo "## QuoteBar v${NEW}"
    echo
    if [[ -n "$PREV_TAG" ]]; then
      echo "自 ${PREV_TAG} 以来的提交："
      echo
      git log --pretty=format:'- %s' "${PREV_TAG}..HEAD"
      echo
    else
      echo "全部提交："
      echo
      git log --pretty=format:'- %s'
      echo
    fi
  } > "$notes"
}

commit_pending_work

echo "$NEW" > VERSION
echo "$NEW_BUILD" > BUILD
plutil -replace CFBundleShortVersionString -string "$NEW" Resources/Info.plist
plutil -replace CFBundleVersion -string "$NEW_BUILD" Resources/Info.plist
perl -pi -e "s/return \"[0-9]+\\.[0-9]+\\.[0-9]+\"/return \"$NEW\"/" Sources/QuoteBar/AppVersion.swift

git add VERSION BUILD Resources/Info.plist Sources/QuoteBar/AppVersion.swift
git commit -m "release: v${NEW}"
git tag "v${NEW}"

NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
write_notes "$NOTES"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "creating private GitHub repo $REPO"
  gh repo create "$REPO" --private --source=. --remote=origin --push
else
  git push -u origin HEAD
fi

git push origin "v${NEW}"
gh release create "v${NEW}" --repo "$REPO" --title "QuoteBar v${NEW}" --notes-file "$NOTES"
echo "Release v${NEW} pushed. CI will attach QuoteBar-${NEW}.dmg"
