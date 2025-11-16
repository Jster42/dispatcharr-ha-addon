#!/usr/bin/env bash
# Script to manually fix nginx config inside running container
# Usage: ./tools/fix_nginx_in_container.sh

set -euo pipefail

# Load .env file if it exists
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

echo "=== Fixing nginx config in running container ==="
echo ""

# Find container
CONTAINER=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker ps | grep dispatcharr | awk '{print \$1}'" | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Container not found!"
    exit 1
fi

echo "Container ID: $CONTAINER"
echo ""

echo "Running fix commands inside container..."
echo ""

# Clean up .bak files
echo "1. Cleaning up .bak files..."
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER bash -c 'rm -f /etc/nginx/sites-enabled/default.bak 2>/dev/null || true'"
echo "   ✅ Done"
echo ""

# Check current config
echo "2. Current location / block:"
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER sed -n '/location \/ {/,/^    }/p' /etc/nginx/sites-enabled/default | head -10"
echo ""

# Add uwsgi_buffering if missing
echo "3. Adding uwsgi_buffering off..."
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER bash -c '
NGINX_CONF=\"/etc/nginx/sites-enabled/default\"
if ! grep -q \"uwsgi_buffering off\" \"\$NGINX_CONF\" 2>/dev/null; then
    # Use awk to add after first uwsgi_pass only
    awk \"/uwsgi_pass unix:\\/app\\/uwsgi.sock;/ && !done { print; print \"        uwsgi_buffering off;\"; print \"        uwsgi_request_buffering off;\"; done=1; next } {print}\" \"\$NGINX_CONF\" > \"\${NGINX_CONF}.tmp\" && mv \"\${NGINX_CONF}.tmp\" \"\$NGINX_CONF\"
    echo \"   ✅ Added\"
else
    echo \"   Already present\"
fi
'"
echo ""

# Verify config
echo "4. Testing nginx config..."
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER nginx -t 2>&1"
echo ""

# Reload nginx
echo "5. Reloading nginx..."
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER nginx -s reload 2>&1 && echo '   ✅ Nginx reloaded' || echo '   ⚠️ Reload failed'"
echo ""

# Verify the fix
echo "6. Verifying fix..."
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER bash -c '
if grep -q \"uwsgi_buffering off\" /etc/nginx/sites-enabled/default 2>/dev/null; then
    echo \"   ✅ uwsgi_buffering is now disabled\"
    echo \"   Location / block:\"
    sed -n \"/location \\/ {/,/^    }/p\" /etc/nginx/sites-enabled/default | grep -A 3 \"uwsgi_pass\"
else
    echo \"   ❌ uwsgi_buffering still not found!\"
fi
'"
echo ""

echo ""
echo "=== Testing response after fix ==="
echo ""

# Test the response
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER bash -c 'echo \"Response size:\" && curl -s http://localhost:9191/ | wc -c'"

echo ""
echo "Now try accessing Ingress again and check if the access logs show 772 bytes instead of 396 bytes."

