#!/usr/bin/env bash
# Script to test Ingress from inside the container
# Usage: ./tools/test_in_container.sh

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

echo "=== Testing Ingress from inside container ==="
echo ""

# Find container
CONTAINER=$(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker ps | grep dispatcharr | awk '{print \$1}'" | head -1)

if [ -z "$CONTAINER" ]; then
    echo "❌ Container not found!"
    exit 1
fi

echo "Container ID: $CONTAINER"
echo ""

# Create test script inside container
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER bash -c 'cat > /tmp/test_ingress.sh << \"TESTEOF\"
#!/bin/bash
set -euo pipefail

echo \"=== Ingress Diagnostic Tests ===\"
echo \"\"

# Test 1: Basic response
echo \"1. Testing basic HTTP response...\"
RESPONSE=\$(curl -s http://localhost:9191/)
SIZE=\$(echo \"\$RESPONSE\" | wc -c)
echo \"   Response size: \$SIZE bytes\"
echo \"   First 100 chars: \$(echo \"\$RESPONSE\" | head -c 100)\"
echo \"\"

# Test 2: Response with Supervisor headers
echo \"2. Testing with Supervisor IP headers (simulating Ingress proxy)...\"
RESPONSE2=\$(curl -s -H \"X-Forwarded-For: 172.30.32.2\" -H \"X-Real-IP: 172.30.32.2\" -H \"X-Forwarded-Host: homeassistant.local\" http://localhost:9191/)
SIZE2=\$(echo \"\$RESPONSE2\" | wc -c)
echo \"   Response size: \$SIZE2 bytes\"
if [ \"\$SIZE2\" != \"\$SIZE\" ]; then
    echo \"   ⚠️ WARNING: Size mismatch! Basic: \$SIZE, With headers: \$SIZE2\"
fi
echo \"\"

# Test 3: Check response headers
echo \"3. Checking response headers...\"
curl -s -I http://localhost:9191/ | grep -E \"Content-Length|Content-Type|Connection|Transfer-Encoding\" || true
echo \"\"

# Test 4: Test with keep-alive
echo \"4. Testing with keep-alive connection...\"
curl -s -H \"Connection: keep-alive\" http://localhost:9191/ | wc -c
echo \"\"

# Test 5: Check nginx config
echo \"5. Checking nginx configuration...\"
echo \"   Listen directive:\"
grep \"listen\" /etc/nginx/sites-enabled/default | head -1
echo \"   uwsgi_buffering settings:\"
grep -A 5 \"location /\" /etc/nginx/sites-enabled/default | grep -i buffering || echo \"   No buffering settings found\"
echo \"\"

# Test 6: Check if response is being streamed correctly
echo \"6. Testing response streaming...\"
timeout 5 curl -s -N http://localhost:9191/ | head -c 400 | wc -c
echo \"   (Should be 400 bytes if streaming works)\"
echo \"\"

# Test 7: Check nginx error log for truncation
echo \"7. Checking nginx error log for truncation issues...\"
if [ -f /var/log/nginx/error.log ]; then
    tail -20 /var/log/nginx/error.log | grep -i \"truncat\|incomplete\|timeout\" || echo \"   No truncation errors found\"
else
    echo \"   No error log found\"
fi
echo \"\"

# Test 8: Test actual byte-by-byte transfer
echo \"8. Testing byte transfer simulation...\"
BYTES=\$(curl -s -w \"%{size_download}\" -o /dev/null http://localhost:9191/)
echo \"   Bytes downloaded: \$BYTES\"
echo \"\"

# Test 9: Check uWSGI response
echo \"9. Testing uWSGI socket directly (if possible)...\"
if [ -S /app/uwsgi.sock ]; then
    echo \"   Socket exists and is accessible\"
    # Try to get response size via uwsgi
    echo \"   (Cannot directly test uwsgi socket from bash)\"
else
    echo \"   ⚠️ uWSGI socket not found\"
fi
echo \"\"

# Test 10: Compare response content
echo \"10. Comparing response content (first 396 bytes vs full)...\"
FULL=\$(curl -s http://localhost:9191/)
FIRST_396=\$(echo \"\$FULL\" | head -c 396)
echo \"   First 396 bytes end with: \$(echo \"\$FIRST_396\" | tail -c 50)\"
echo \"   Byte 397-400: \$(echo \"\$FULL\" | head -c 400 | tail -c 4)\"
echo \"\"

echo \"=== Tests Complete ===\"
TESTEOF
chmod +x /tmp/test_ingress.sh'"

echo "Running tests inside container..."
echo ""

# Execute the test script
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "sudo docker exec $CONTAINER /tmp/test_ingress.sh"

echo ""
echo "=== Additional Manual Tests ==="
echo ""
echo "You can also run these commands manually inside the container:"
echo ""
echo "1. Test response size:"
echo "   docker exec $CONTAINER curl -s http://localhost:9191/ | wc -c"
echo ""
echo "2. Test with verbose output:"
echo "   docker exec $CONTAINER curl -v http://localhost:9191/ 2>&1 | grep -E '< HTTP|< Content|bytes'"
echo ""
echo "3. Check nginx config:"
echo "   docker exec $CONTAINER cat /etc/nginx/sites-enabled/default | grep -A 5 'location /'"
echo ""
echo "4. Monitor access log in real-time:"
echo "   docker exec $CONTAINER tail -f /var/log/nginx/access.log"
echo ""

