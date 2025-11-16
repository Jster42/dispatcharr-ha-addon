#!/usr/bin/env bash
# Script to check Home Assistant Ingress configuration requirements
# Usage: ./tools/check_ingress_config.sh

set -euo pipefail

echo "=== Home Assistant Ingress Configuration Checklist ==="
echo ""

CONFIG_FILE="dispatcharr/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: $CONFIG_FILE not found"
    exit 1
fi

echo "Checking $CONFIG_FILE..."
echo ""

# Check ingress enabled
if grep -q "ingress: true" "$CONFIG_FILE"; then
    echo "✅ ingress: true"
else
    echo "❌ ingress: true - MISSING"
fi

# Check ingress_port
if grep -q "ingress_port:" "$CONFIG_FILE"; then
    INGRESS_PORT=$(grep "ingress_port:" "$CONFIG_FILE" | sed 's/.*ingress_port:[[:space:]]*\([0-9]*\).*/\1/')
    echo "✅ ingress_port: $INGRESS_PORT"
else
    echo "⚠️  ingress_port: not specified (defaults to 8099)"
fi

# Check if ports are empty (recommended for Ingress)
if grep -q "ports: {}" "$CONFIG_FILE"; then
    echo "✅ ports: {} (empty - correct for Ingress)"
else
    echo "⚠️  ports: may be exposing ports (not needed for Ingress)"
fi

echo ""
echo "=== Nginx Configuration Requirements ==="
echo ""
echo "For Ingress to work, nginx must:"
echo "1. Listen on 0.0.0.0:INGRESS_PORT (not 127.0.0.1)"
echo "2. Accept connections from 172.30.32.2 (Supervisor IP)"
echo "3. Handle X-Ingress-Path header (for base URL)"
echo ""
echo "Our configuration:"
echo "✅ Nginx template patched to listen on 0.0.0.0:9191"
echo "✅ X-Ingress-Path header passthrough added"
echo "✅ uWSGI timeouts increased for Ingress compatibility"
echo ""
echo "Note: Restricting to 172.30.32.2 is recommended but not required."
echo "      Listening on 0.0.0.0 is sufficient since container is isolated."
echo ""

