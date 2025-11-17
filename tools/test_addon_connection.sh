#!/usr/bin/env bash
# Test if Dispatcharr addon is accessible
# Usage: ./tools/test_addon_connection.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

SSH_HOST="${SSH_HOST:-homeassistant.local}"
SSH_USER="${SSH_USER:-hassio}"
SSH_PASSWORD="${SSH_PASSWORD:-}"

if [ -z "$SSH_PASSWORD" ]; then
    echo "Error: SSH_PASSWORD must be set in .env file"
    exit 1
fi

export SSHPASS="$SSH_PASSWORD"

echo "=== Testing Dispatcharr Addon Connection ==="
echo ""

# Find container
CONTAINER=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker ps | grep dispatcharr | awk '{print \$1}'" | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Dispatcharr container is not running!"
    echo ""
    echo "Check addon status in Home Assistant:"
    echo "  Settings → Add-ons → Dispatcharr"
    echo ""
    exit 1
fi

echo "✅ Container is running: $CONTAINER"
echo ""

# Check if port is listening inside container
echo "1. Checking if port 9191 is listening inside container..."
LISTENING=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER ss -tlnp 2>/dev/null | grep 9191 || sudo docker exec $CONTAINER netstat -tlnp 2>/dev/null | grep 9191" || echo "")
if [ -n "$LISTENING" ]; then
    echo "   ✅ Port 9191 is listening:"
    echo "   $LISTENING"
else
    echo "   ❌ Port 9191 is NOT listening!"
fi
echo ""

# Test from inside container
echo "2. Testing HTTP connection from inside container..."
HTTP_TEST=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:9191/ 2>&1" || echo "FAILED")
if [ "$HTTP_TEST" = "200" ]; then
    echo "   ✅ HTTP 200 - Service is responding"
else
    echo "   ❌ HTTP $HTTP_TEST - Service not responding correctly"
fi
echo ""

# Check container port mapping
echo "3. Checking container port mapping..."
PORT_MAP=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker port $CONTAINER 2>/dev/null | grep 9191 || echo 'No port mapping found'")
echo "   $PORT_MAP"
echo ""

# Test from HA host
echo "4. Testing connection from HA host (localhost:9191)..."
HA_TEST=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:9191/ 2>&1" || echo "FAILED")
if [ "$HA_TEST" = "200" ]; then
    echo "   ✅ HTTP 200 - Accessible from HA host"
else
    echo "   ❌ HTTP $HA_TEST - Not accessible from HA host"
    echo "   This might be a port mapping issue"
fi
echo ""

# Get HA IP
echo "5. Getting Home Assistant IP address..."
HA_IP=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "hostname -I | awk '{print \$1}'" || echo "unknown")
echo "   HA IP: $HA_IP"
echo ""
echo "Try accessing: http://$HA_IP:9191"
echo "   or: http://homeassistant.local:9191"
echo ""

# Check addon logs for errors
echo "6. Recent addon logs (last 10 lines):"
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker logs $CONTAINER --tail 10 2>&1" || echo "Could not get logs"
echo ""

echo "=== Summary ==="
if [ "$HTTP_TEST" = "200" ] && [ "$HA_TEST" = "200" ]; then
    echo "✅ Addon appears to be working!"
    echo "   Access it at: http://$HA_IP:9191"
elif [ "$HTTP_TEST" = "200" ] && [ "$HA_TEST" != "200" ]; then
    echo "⚠️ Service is running but port may not be mapped correctly"
    echo "   Check addon configuration in Home Assistant"
else
    echo "❌ Service is not responding correctly"
    echo "   Check addon logs in Home Assistant"
fi
