#!/usr/bin/env bash
# Check Home Assistant logs for repository issues
# Usage: ./tools/check_repo_logs.sh [api|ssh]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

METHOD="${1:-api}"

case "$METHOD" in
    api)
        HA_URL="${HA_URL:-}"
        HA_TOKEN="${HA_TOKEN:-}"
        
        if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
            echo "Usage: $0 api"
            echo "   OR: Set HA_URL and HA_TOKEN in .env file"
            exit 1
        fi
        
        HA_URL="${HA_URL%/}"
        
        echo "=== Checking Supervisor logs via API ==="
        echo ""
        
        LOGS=$(curl -s -X GET \
            -H "Authorization: Bearer $HA_TOKEN" \
            -H "Content-Type: application/json" \
            "$HA_URL/api/hassio/supervisor/logs" 2>&1)
        
        echo "1. Repository-related errors:"
        echo "$LOGS" | grep -i -E "repository|dispatcharr" | tail -20 || echo "No repository errors found"
        echo ""
        
        echo "2. Addon store errors:"
        echo "$LOGS" | grep -i -E "addon.*store|store.*error" | tail -20 || echo "No store errors found"
        echo ""
        
        echo "3. Validation/parse errors:"
        echo "$LOGS" | grep -i -E "validation|yaml|parse|syntax|invalid" | tail -20 || echo "No validation errors found"
        echo ""
        
        echo "4. Recent errors (last 30 lines):"
        echo "$LOGS" | grep -i "error" | tail -30 || echo "No errors found"
        ;;
        
    ssh)
        SSH_HOST="${SSH_HOST:-homeassistant.local}"
        SSH_USER="${SSH_USER:-hassio}"
        SSH_PASSWORD="${SSH_PASSWORD:-}"
        
        if [ -z "$SSH_PASSWORD" ]; then
            echo "Usage: $0 ssh"
            echo "   OR: Set SSH_HOST, SSH_USER, SSH_PASSWORD in .env file"
            exit 1
        fi
        
        export SSHPASS="$SSH_PASSWORD"
        
        echo "=== Checking Supervisor logs via SSH ==="
        echo ""
        
        echo "1. Repository-related logs:"
        sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" \
            "sudo journalctl -u hassio-supervisor --no-pager -n 200 2>/dev/null | grep -i -E 'repository|dispatcharr' | tail -20" || \
        sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" \
            "ha supervisor logs 2>/dev/null | grep -i -E 'repository|dispatcharr' | tail -20" || \
        echo "Could not access logs"
        echo ""
        
        echo "2. Recent Supervisor errors:"
        sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" \
            "sudo journalctl -u hassio-supervisor --no-pager -n 100 2>/dev/null | grep -i error | tail -20" || \
        sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" \
            "ha supervisor logs 2>/dev/null | grep -i error | tail -20" || \
        echo "Could not access logs"
        ;;
        
    *)
        echo "Usage: $0 [api|ssh]"
        echo ""
        echo "Check Home Assistant Supervisor logs for repository issues"
        exit 1
        ;;
esac
