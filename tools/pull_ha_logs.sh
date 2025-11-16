#!/usr/bin/env bash
# Script to pull Home Assistant logs for debugging Ingress issues
# Usage: ./tools/pull_ha_logs.sh [method] [host] [options]

set -euo pipefail

METHOD="${1:-ssh}"
HOST="${2:-}"
SSH_USER="${3:-root}"
SSH_KEY="${4:-}"

case "$METHOD" in
    ssh)
        if [ -z "$HOST" ]; then
            echo "Usage: $0 ssh <host> [user] [ssh_key]"
            echo "Example: $0 ssh homeassistant.local root ~/.ssh/id_rsa"
            exit 1
        fi
        
        echo "Connecting to $HOST as $SSH_USER..."
        
        SSH_CMD="ssh"
        if [ -n "$SSH_KEY" ]; then
            SSH_CMD="$SSH_CMD -i $SSH_KEY"
        fi
        SSH_CMD="$SSH_CMD $SSH_USER@$HOST"
        
        echo ""
        echo "=== Supervisor Logs (filtered for ingress) ==="
        $SSH_CMD "journalctl -u hassio-supervisor --no-pager | grep -i ingress | tail -50"
        
        echo ""
        echo "=== Supervisor Logs (all recent) ==="
        $SSH_CMD "journalctl -u hassio-supervisor --no-pager -n 100"
        
        echo ""
        echo "=== Docker container status ==="
        $SSH_CMD "docker ps | grep dispatcharr"
        
        echo ""
        echo "=== Check nginx in container ==="
        CONTAINER=$($SSH_CMD "docker ps | grep dispatcharr | awk '{print \$1}'" | head -1)
        if [ -n "$CONTAINER" ]; then
            echo "Container ID: $CONTAINER"
            echo ""
            echo "Nginx listening ports:"
            $SSH_CMD "docker exec $CONTAINER ss -tlnp | grep nginx || docker exec $CONTAINER netstat -tlnp | grep nginx || echo 'Could not check ports'"
            echo ""
            echo "Nginx config listen directive:"
            $SSH_CMD "docker exec $CONTAINER grep -E 'listen[[:space:]]+[0-9]' /etc/nginx/sites-enabled/default | head -3"
            echo ""
            echo "Nginx error log (last 20 lines):"
            $SSH_CMD "docker exec $CONTAINER tail -20 /var/log/nginx/error.log 2>/dev/null || echo 'No nginx error log found'"
        fi
        ;;
        
    api)
        # Load .env file if it exists (in repo root or script directory)
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
        
        if [ -z "$HOST" ]; then
            HOST="${HA_URL:-}"
        fi
        
        if [ -z "$HOST" ]; then
            echo "Usage: $0 api <ha_url> [token]"
            echo "   OR: Set HA_URL and HA_TOKEN in .env file"
            echo ""
            echo "Example: $0 api http://homeassistant.local:8123 eyJ0eXAiOiJKV1QiLCJhbGc..."
            echo ""
            echo ".env file format:"
            echo "  HA_URL=http://homeassistant.local:8123"
            echo "  HA_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGc..."
            echo ""
            echo "To get a token:"
            echo "1. Go to Home Assistant → Profile → Long-Lived Access Tokens"
            echo "2. Create a new token"
            exit 1
        fi
        
        TOKEN="${3:-${HA_TOKEN:-}}"
        if [ -z "$TOKEN" ]; then
            echo "Error: API token required"
            echo "Either provide it as argument or set HA_TOKEN in .env file"
            exit 1
        fi
        
        HA_URL="${HOST%/}"
        
        # Check if jq is installed
        if ! command -v jq >/dev/null 2>&1; then
            echo "Warning: jq is not installed. Installing via brew or showing raw JSON..."
            echo "You can install it with: brew install jq"
            echo ""
            USE_JQ=false
        else
            USE_JQ=true
        fi
        
        echo "Fetching logs from Home Assistant API..."
        echo "HA URL: $HA_URL"
        echo ""
        
        # Get supervisor logs via API
        echo "=== Supervisor Logs ==="
        SUPERVISOR_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/supervisor/logs" 2>&1)
        
        HTTP_STATUS=$(echo "$SUPERVISOR_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        SUPERVISOR_BODY=$(echo "$SUPERVISOR_RESPONSE" | sed '/HTTP_STATUS:/d')
        
        if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" != "200" ]; then
            echo "Error: Failed to fetch supervisor logs (HTTP ${HTTP_STATUS:-unknown})"
            echo "Response preview:"
            echo "$SUPERVISOR_BODY" | head -10
            echo ""
            echo "Note: Supervisor API might require different endpoint or permissions"
        else
            # Check if response is JSON
            if echo "$SUPERVISOR_BODY" | head -1 | grep -q "^{"; then
                if [ "$USE_JQ" = true ]; then
                    echo "$SUPERVISOR_BODY" | jq -r '.data // .' 2>/dev/null | tail -100 || {
                        echo "Failed to parse JSON, showing raw response:"
                        echo "$SUPERVISOR_BODY" | head -50
                    }
                else
                    echo "$SUPERVISOR_BODY" | grep -o '"data":"[^"]*"' | sed 's/"data":"//;s/"$//' | tail -100 || echo "$SUPERVISOR_BODY" | head -50
                fi
            else
                echo "Response is not JSON, showing raw output:"
                echo "$SUPERVISOR_BODY" | head -50
            fi
        fi
        
        # Get addon logs
        echo ""
        echo "=== Dispatcharr Add-on Logs ==="
        ADDON_LOG_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/local/dispatcharr/logs" 2>&1)
        
        HTTP_STATUS=$(echo "$ADDON_LOG_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        ADDON_LOG_BODY=$(echo "$ADDON_LOG_RESPONSE" | sed '/HTTP_STATUS:/d')
        
        if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" != "200" ]; then
            echo "Error: Failed to fetch addon logs (HTTP ${HTTP_STATUS:-unknown})"
            echo "Response preview:"
            echo "$ADDON_LOG_BODY" | head -10
        else
            # Check if response is JSON
            if echo "$ADDON_LOG_BODY" | head -1 | grep -q "^{"; then
                if [ "$USE_JQ" = true ]; then
                    echo "$ADDON_LOG_BODY" | jq -r '.data // .' 2>/dev/null | tail -100 || {
                        echo "Failed to parse JSON, showing raw response:"
                        echo "$ADDON_LOG_BODY" | head -50
                    }
                else
                    echo "$ADDON_LOG_BODY" | grep -o '"data":"[^"]*"' | sed 's/"data":"//;s/"$//' | tail -100 || echo "$ADDON_LOG_BODY" | head -50
                fi
            else
                echo "Response is not JSON, showing raw output:"
                echo "$ADDON_LOG_BODY" | head -50
            fi
        fi
        
        # Get addon info
        echo ""
        echo "=== Dispatcharr Add-on Info ==="
        ADDON_INFO_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/local/dispatcharr/info" 2>&1)
        
        HTTP_STATUS=$(echo "$ADDON_INFO_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        ADDON_INFO_BODY=$(echo "$ADDON_INFO_RESPONSE" | sed '/HTTP_STATUS:/d')
        
        if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" != "200" ]; then
            echo "Error: Failed to fetch addon info (HTTP ${HTTP_STATUS:-unknown})"
            echo "Response preview:"
            echo "$ADDON_INFO_BODY" | head -10
            echo ""
            echo "Trying alternative endpoint..."
            # Try without /local/ prefix
            ADDON_INFO_RESPONSE2=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $TOKEN" \
                 -H "Content-Type: application/json" \
                 "$HA_URL/api/hassio/addons/dispatcharr/info" 2>&1)
            HTTP_STATUS2=$(echo "$ADDON_INFO_RESPONSE2" | grep "HTTP_STATUS:" | cut -d: -f2)
            ADDON_INFO_BODY2=$(echo "$ADDON_INFO_RESPONSE2" | sed '/HTTP_STATUS:/d')
            if [ "$HTTP_STATUS2" = "200" ]; then
                if [ "$USE_JQ" = true ]; then
                    echo "$ADDON_INFO_BODY2" | jq '.data | {name, version, state, ingress, ingress_port}' 2>/dev/null || echo "$ADDON_INFO_BODY2"
                else
                    echo "$ADDON_INFO_BODY2"
                fi
            fi
        else
            if [ "$USE_JQ" = true ]; then
                echo "$ADDON_INFO_BODY" | jq '.data | {name, version, state, ingress, ingress_port}' 2>/dev/null || echo "$ADDON_INFO_BODY"
            else
                echo "$ADDON_INFO_BODY"
            fi
        fi
        
        # Try to get ingress-specific logs
        echo ""
        echo "=== Checking Ingress Status ==="
        INGRESS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/ingress/sessions" 2>/dev/null || echo "HTTP_STATUS:404")
        
        HTTP_STATUS=$(echo "$INGRESS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "Ingress sessions found"
        else
            echo "Could not fetch ingress sessions (this is normal)"
        fi
        ;;
        
    docker)
        # Direct docker access (if running on same machine or via docker context)
        echo "=== Docker containers ==="
        docker ps | grep dispatcharr || echo "No dispatcharr container found"
        
        CONTAINER=$(docker ps | grep dispatcharr | awk '{print $1}' | head -1)
        if [ -n "$CONTAINER" ]; then
            echo ""
            echo "Container ID: $CONTAINER"
            echo ""
            echo "Nginx listening ports:"
            docker exec $CONTAINER ss -tlnp 2>/dev/null | grep nginx || \
            docker exec $CONTAINER netstat -tlnp 2>/dev/null | grep nginx || \
            echo "Could not check ports"
            echo ""
            echo "Nginx config:"
            docker exec $CONTAINER grep -E 'listen[[:space:]]+[0-9]' /etc/nginx/sites-enabled/default | head -3
            echo ""
            echo "Container logs (last 50 lines):"
            docker logs --tail 50 $CONTAINER
        fi
        ;;
        
    *)
        echo "Unknown method: $METHOD"
        echo ""
        echo "Available methods:"
        echo "  ssh    - Connect via SSH (requires SSH access to HA host)"
        echo "  api    - Use Home Assistant API (requires long-lived token)"
        echo "  docker - Direct docker access (if on same machine)"
        exit 1
        ;;
esac

