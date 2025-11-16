#!/usr/bin/env bash
# Script to update and restart Dispatcharr addon via Home Assistant API
# Usage: ./tools/update_addon.sh [restart]

set -euo pipefail

# Load .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
elif [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

HA_URL="${HA_URL:-}"
HA_TOKEN="${HA_TOKEN:-}"
ADDON_SLUG="${ADDON_SLUG:-dispatcharr}"
RESTART="${1:-}"

if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
    echo "Error: HA_URL and HA_TOKEN must be set in .env file or environment"
    echo ""
    echo "Create a .env file in the repo root with:"
    echo "  HA_URL=http://homeassistant.local:8123"
    echo "  HA_TOKEN=your_long_lived_access_token"
    exit 1
fi

HA_URL="${HA_URL%/}"

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is not installed. Install with: brew install jq"
    USE_JQ=false
else
    USE_JQ=true
fi

echo "Updating Dispatcharr addon via Home Assistant API..."
echo "HA URL: $HA_URL"
echo "Addon: $ADDON_SLUG"
echo ""

# First, try to get addon info to find the correct slug
echo "=== Finding addon ==="
ADDON_INFO=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/addons" 2>&1)

if echo "$ADDON_INFO" | grep -q "401\|Unauthorized"; then
    echo "Error: Authentication failed (401)"
    exit 1
fi

# Try to find the addon slug (could be local/dispatcharr or just dispatcharr)
ADDON_SLUG_FOUND=""
if [ "$USE_JQ" = true ]; then
    ADDON_SLUG_FOUND=$(echo "$ADDON_INFO" | jq -r '.data.addons[] | select(.slug == "dispatcharr" or .slug == "local_dispatcharr" or .name == "Dispatcharr") | .slug' 2>/dev/null | head -1)
fi

if [ -z "$ADDON_SLUG_FOUND" ]; then
    # Try common variations
    for slug in "local/dispatcharr" "dispatcharr" "local_dispatcharr"; do
        TEST_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $HA_TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/$slug/info" 2>&1)
        HTTP_STATUS=$(echo "$TEST_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        if [ "$HTTP_STATUS" = "200" ]; then
            ADDON_SLUG_FOUND="$slug"
            break
        fi
    done
fi

if [ -z "$ADDON_SLUG_FOUND" ]; then
    echo "Error: Could not find Dispatcharr addon"
    echo "Available addons:"
    if [ "$USE_JQ" = true ]; then
        echo "$ADDON_INFO" | jq -r '.data.addons[] | "  - \(.slug) (\(.name))"' 2>/dev/null || echo "$ADDON_INFO" | head -20
    else
        echo "$ADDON_INFO" | head -20
    fi
    exit 1
fi

echo "Found addon: $ADDON_SLUG_FOUND"
echo ""

# Get current version
echo "=== Current Addon Info ==="
CURRENT_INFO=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/addons/$ADDON_SLUG_FOUND/info" 2>&1)

if [ "$USE_JQ" = true ]; then
    CURRENT_VERSION=$(echo "$CURRENT_INFO" | jq -r '.data.version // "unknown"' 2>/dev/null)
    CURRENT_STATE=$(echo "$CURRENT_INFO" | jq -r '.data.state // "unknown"' 2>/dev/null)
    echo "Current version: $CURRENT_VERSION"
    echo "Current state: $CURRENT_STATE"
else
    echo "$CURRENT_INFO" | head -30
fi
echo ""

# Check for updates
echo "=== Checking for updates ==="
UPDATE_CHECK=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/addons/$ADDON_SLUG_FOUND/update" 2>&1)

# Actually, the update endpoint might be different. Let's try to refresh the store first
echo "Refreshing addon store..."
STORE_REFRESH=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/store/reload" 2>&1)

HTTP_STATUS=$(echo "$STORE_REFRESH" | grep "HTTP_STATUS:" | cut -d: -f2)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "Store refreshed successfully"
else
    echo "Store refresh returned HTTP $HTTP_STATUS (this is usually OK)"
fi
echo ""

# Update the addon
echo "=== Updating addon ==="
UPDATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
     -H "Authorization: Bearer $HA_TOKEN" \
     -H "Content-Type: application/json" \
     "$HA_URL/api/hassio/addons/$ADDON_SLUG_FOUND/update" 2>&1)

HTTP_STATUS=$(echo "$UPDATE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
UPDATE_BODY=$(echo "$UPDATE_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Addon update initiated successfully"
    
    # Wait a bit for update to complete
    echo "Waiting for update to complete..."
    sleep 5
    
    # Check new version
    NEW_INFO=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
         -H "Content-Type: application/json" \
         "$HA_URL/api/hassio/addons/$ADDON_SLUG_FOUND/info" 2>&1)
    
    if [ "$USE_JQ" = true ]; then
        NEW_VERSION=$(echo "$NEW_INFO" | jq -r '.data.version // "unknown"' 2>/dev/null)
        echo "New version: $NEW_VERSION"
    fi
    
    # Restart if requested or if addon was running
    if [ "$RESTART" = "restart" ] || [ "$CURRENT_STATE" = "started" ]; then
        echo ""
        echo "=== Restarting addon ==="
        RESTART_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
             -H "Authorization: Bearer $HA_TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/$ADDON_SLUG_FOUND/restart" 2>&1)
        
        HTTP_STATUS=$(echo "$RESTART_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "✅ Addon restart initiated"
        else
            echo "⚠️ Restart returned HTTP $HTTP_STATUS"
            echo "$RESTART_RESPONSE" | sed '/HTTP_STATUS:/d' | head -10
        fi
    else
        echo ""
        echo "Addon is not running. Start it manually or run:"
        echo "  $0 restart"
    fi
else
    echo "Error: Update failed (HTTP $HTTP_STATUS)"
    echo "Response:"
    echo "$UPDATE_BODY" | head -20
    exit 1
fi

echo ""
echo "Done! Check the addon logs to verify it's running correctly."

