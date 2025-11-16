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
        if [ -z "$HOST" ]; then
            echo "Usage: $0 api <ha_url> [token]"
            echo "Example: $0 api http://homeassistant.local:8123 eyJ0eXAiOiJKV1QiLCJhbGc..."
            echo ""
            echo "To get a token:"
            echo "1. Go to Home Assistant → Profile → Long-Lived Access Tokens"
            echo "2. Create a new token"
            exit 1
        fi
        
        TOKEN="${3:-}"
        if [ -z "$TOKEN" ]; then
            echo "Error: API token required"
            exit 1
        fi
        
        HA_URL="${HOST%/}"
        
        echo "Fetching logs from Home Assistant API..."
        
        # Get supervisor logs via API
        echo ""
        echo "=== Supervisor Logs ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/supervisor/logs" | jq -r '.data' | tail -100
        
        # Get addon logs
        echo ""
        echo "=== Dispatcharr Add-on Logs ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/local/dispatcharr/logs" | jq -r '.data' | tail -100
        
        # Get addon info
        echo ""
        echo "=== Dispatcharr Add-on Info ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/addons/local/dispatcharr/info" | jq '.data | {name, version, state, ingress, ingress_port}'
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

