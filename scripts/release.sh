#!/usr/bin/env bash
# Release script for autoresearch plugin.
# Bumps versions, commits directly to master, pushes, tags, and creates
# a GitHub release.
#
# Usage: ./scripts/release.sh <version> [--title "Release title"]
# Example: ./scripts/release.sh 1.7.0 --title "New Feature X"
#
# Versioning:
#   v1.6.X  — patch: bugfixes, small updates
#   v1.X.0  — minor: new features, significant changes
#   v2.0.0+ — major: reserved for future

set -euo pipefail

# --- Parse arguments ---
VERSION=""
TITLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    *) VERSION="${VERSION:-$1}"; shift ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: ./scripts/release.sh <version> [--title \"Release title\"]"
  echo ""
  echo "Versioning guide:"
  echo "  v1.6.X  — patch: bugfixes, small updates"
  echo "  v1.X.0  — minor: new features, significant changes"
  echo ""
  echo "Example: ./scripts/release.sh 1.7.0 --title \"Scenario Explorer\""
  exit 1
fi

# Strip leading 'v' if provided
VERSION="${VERSION#v}"
TAG="v${VERSION}"
PLUGIN_JSON="claude-plugin/.claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# --- Preflight checks ---
if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "Error: $PLUGIN_JSON not found. Run from repo root."
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install: https://cli.github.com"
  exit 1
fi

# Ensure gh has a default repo set
if ! gh repo view --json nameWithOwner -q .nameWithOwner &>/dev/null; then
  echo "Setting default remote for gh CLI..."
  gh repo set-default
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is dirty. Commit or stash changes first."
  exit 1
fi

# Ensure we're on master
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "master" ]]; then
  echo "Error: Must be on master branch. Currently on: $CURRENT_BRANCH"
  exit 1
fi

git pull origin master --quiet

# Check if tag already exists
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "Error: Tag $TAG already exists. Choose a different version."
  exit 1
fi

# Read current version
CURRENT=$(grep -o '"version": "[^"]*"' "$PLUGIN_JSON" | cut -d'"' -f4)
echo ""
echo "=== autoresearch release ==="
echo "  Current version: $CURRENT"
echo "  New version:     $VERSION"
echo "  Tag:             $TAG"
echo ""

# --- Bump version in plugin.json and marketplace.json ---
echo "[1/5] Bumping versions: $CURRENT → $VERSION"
for JSON_FILE in "$PLUGIN_JSON" "$MARKETPLACE_JSON"; do
  if [[ -f "$JSON_FILE" ]]; then
    echo "    Updating $JSON_FILE"
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s/\"version\": \"$CURRENT\"/\"version\": \"$VERSION\"/g" "$JSON_FILE"
    else
      sed -i "s/\"version\": \"$CURRENT\"/\"version\": \"$VERSION\"/g" "$JSON_FILE"
    fi
  fi
done

# --- Bump version in distribution SKILL.md ---
DIST_SKILL="claude-plugin/skills/autoresearch/SKILL.md"
if [[ -f "$DIST_SKILL" ]] && grep -q "^version:" "$DIST_SKILL"; then
  echo "    Updating $DIST_SKILL"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" "$DIST_SKILL"
  else
    sed -i "s/^version: .*/version: $VERSION/" "$DIST_SKILL"
  fi
fi

# --- Bump version in SKILL.md frontmatter ---
SKILL_FILE=".claude/skills/autoresearch/SKILL.md"
if [[ -f "$SKILL_FILE" ]] && grep -q "^version:" "$SKILL_FILE"; then
  echo "    Updating $SKILL_FILE"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" "$SKILL_FILE"
  else
    sed -i "s/^version: .*/version: $VERSION/" "$SKILL_FILE"
  fi
fi

# --- Bump version badges in README.md and guide/README.md ---
for DOC_FILE in README.md guide/README.md; do
  if [[ -f "$DOC_FILE" ]] && grep -q "version-.*-blue" "$DOC_FILE"; then
    echo "    Updating version badge in $DOC_FILE"
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s/version-[0-9]*\.[0-9]*\.[0-9]*-blue/version-${VERSION}-blue/" "$DOC_FILE"
    else
      sed -i "s/version-[0-9]*\.[0-9]*\.[0-9]*-blue/version-${VERSION}-blue/" "$DOC_FILE"
    fi
  fi
done

# --- Sync distribution files from .claude/ to claude-plugin/ ---
echo ""
echo "[2/5] Syncing distribution files to claude-plugin/"
if [[ -d ".claude/commands/autoresearch" ]]; then
  cp .claude/commands/autoresearch.md claude-plugin/commands/autoresearch.md
  cp .claude/commands/autoresearch/*.md claude-plugin/commands/autoresearch/
  echo "    Synced claude-plugin/commands/autoresearch/"
fi
if [[ -d ".claude/skills/autoresearch" ]]; then
  cp .claude/skills/autoresearch/SKILL.md claude-plugin/skills/autoresearch/SKILL.md
  cp .claude/skills/autoresearch/references/*.md claude-plugin/skills/autoresearch/references/
  echo "    Synced claude-plugin/skills/autoresearch/"
fi
if [[ -d "claude-plugin/scripts" ]]; then
  mkdir -p claude-plugin/skills/autoresearch/scripts
  cp claude-plugin/scripts/*.sh claude-plugin/skills/autoresearch/scripts/
  echo "    Synced claude-plugin/skills/autoresearch/scripts/"
fi

# --- Doc review prompt ---
echo ""
echo "[3/5] Documentation review"
echo "────────────────────────────────────────"
echo "  Before continuing, review these files for accuracy:"
echo ""
echo "  README.md        — version refs, command table, feature descriptions"
echo "  guide/           — individual command guides, examples, advanced patterns"
echo "  guide/scenario/  — scenario guide, domain examples, edge case patterns"
echo "  CONTRIBUTING.md  — repo structure, file table, sub-command steps"
echo "  COMPARISON.md    — subcommand count, feature comparison table"
echo ""

# Show what changed since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$LAST_TAG" ]]; then
  echo "  Changes since $LAST_TAG:"
  git log "$LAST_TAG"..HEAD --oneline --no-decorate | sed 's/^/    /'
  echo ""
fi

echo "  If any docs need updates, edit them now"
echo "  in another terminal, then come back here and continue."
echo ""
read -rp "  Press ENTER when docs are ready (or 'skip' to continue as-is): " DOC_RESPONSE

if [[ "$DOC_RESPONSE" != "skip" ]]; then
  # Check if README or EXAMPLES were modified
  if [[ -n "$(git status --porcelain -- README.md guide/ CONTRIBUTING.md COMPARISON.md)" ]]; then
    echo "    Staging doc updates..."
    git add README.md guide/ CONTRIBUTING.md COMPARISON.md 2>/dev/null || true
  fi
fi

# --- Commit all release changes ---
echo ""
echo "[4/5] Committing release changes"
git add -A
if git diff --cached --quiet; then
  echo "    No changes to commit."
else
  git commit -m "chore: prepare release $TAG"
fi

# --- Push to master, tag, and release ---
echo ""
echo "[5/5] Pushing to origin/master, tagging, and creating release"
git push origin master

echo "  Creating tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

echo "  Creating GitHub release..."
RELEASE_TITLE="${TAG}"
if [[ -n "$TITLE" ]]; then
  RELEASE_TITLE="$TAG — $TITLE"
fi
gh release create "$TAG" --title "$RELEASE_TITLE" --generate-notes

echo ""
echo "=== Released $TAG ==="
echo "  GitHub release: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
echo "  Plugin version: $VERSION"
