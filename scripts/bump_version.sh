#!/bin/bash

# 自动更新 pyproject.toml 中的版本号

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CURRENT=$(grep "version = " pyproject.toml | head -1 | cut -d'"' -f2)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
    patch)
        PATCH=$((PATCH + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    *)
        echo "用法: $0 [patch|minor|major]"
        echo "  patch  — 0.0.1 → 0.0.2 (默认)"
        echo "  minor  — 0.0.1 → 0.1.0"
        echo "  major  — 0.0.1 → 1.0.0"
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

sed -i '' "s/version = \"$CURRENT\"/version = \"$NEW_VERSION\"/" pyproject.toml

echo "$CURRENT → $NEW_VERSION"
