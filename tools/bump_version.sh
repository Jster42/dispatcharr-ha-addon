#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ADDON_DIR="${HERE%/tools}/dispatcharr"
CONFIG_FILE="$ADDON_DIR/config.yaml"

# Extract current version
CURRENT=$(grep -E '^version:' "$CONFIG_FILE" | sed 's/version: *"\(.*\)"/\1/')

# Increment patch version (0.0.X)
IFS='.' read -ra PARTS <<< "${CURRENT%-*}"
MAJOR="${PARTS[0]:-0}"
MINOR="${PARTS[1]:-0}"
PATCH="${PARTS[2]:-0}"
PATCH=$((PATCH + 1))

# Check if it has a dev suffix
if [[ "$CURRENT" == *"-dev" ]]; then
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}-dev"
else
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

# Update config.yaml
sed -i.bak "s/^version:.*/version: \"$NEW_VERSION\"/" "$CONFIG_FILE"
rm -f "${CONFIG_FILE}.bak"

echo "Version bumped: $CURRENT -> $NEW_VERSION"
echo "Updated: $CONFIG_FILE"

