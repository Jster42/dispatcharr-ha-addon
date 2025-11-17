#!/bin/bash
# Script to refresh Home Assistant addon repository

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

HA_URL="${HA_URL:-${1:-}}"
HA_TOKEN="${HA_TOKEN:-${2:-}}"

if [ -z "$HA_URL" ]; then
    echo "Usage: $0 [ha_url] [token]"
    echo "   OR: Set HA_URL and HA_TOKEN in .env file"
    echo ""
    echo "This script will:"
    echo "1. Refresh the addon store/repositories"
    echo "2. Check the current version"
    exit 1
fi

HA_URL="${HA_URL%/}"

echo "=== Refreshing Home Assistant Addon Repository ==="
echo "HA URL: $HA_URL"
echo ""

# Refresh the store/repositories
echo "1. Refreshing addon repositories..."
STORE_REFRESH=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/store/reload" 2>&1)

HTTP_STATUS=$(echo "$STORE_REFRESH" | grep "HTTP_STATUS:" | cut -d: -f2)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Repository refresh initiated"
    echo ""
    echo "2. Waiting 10 seconds for repository to update..."
    sleep 10
    echo ""
    echo "3. Checking addon info..."
    ADDON_INFO=$(curl -s -X GET \
         -H "Authorization: Bearer $HA_TOKEN" \
         -H "Content-Type: application/json" \
         "$HA_URL/api/hassio/addons" 2>&1)
    
    if command -v jq >/dev/null 2>&1; then
        echo "$ADDON_INFO" | jq '.data.addons[] | select(.slug == "dispatcharr") | {name, slug, version, update_available}' 2>/dev/null || echo "$ADDON_INFO"
    else
        echo "$ADDON_INFO"
    fi
    echo ""
    echo "✅ Done! Check Home Assistant UI for the new version."
    echo ""
    echo "If version still doesn't update:"
    echo "1. Go to Settings → Add-ons → Add-on Store"
    echo "2. Click the ⋮ menu → Repositories"
    echo "3. Find your repository and click the refresh icon"
    echo "4. Then check the Dispatcharr addon again"
else
    echo "⚠️ Repository refresh returned HTTP $HTTP_STATUS"
    echo ""
    echo "Manual steps:"
    echo "1. Go to Settings → Add-ons → Add-on Store"
    echo "2. Click the ⋮ menu → Repositories"
    echo "3. Find your repository and click the refresh icon"
    echo "4. Wait 10-30 seconds"
    echo "5. Check the Dispatcharr addon - it should show version 1.0.47-dev"
fi
