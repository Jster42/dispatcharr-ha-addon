#!/usr/bin/env bash
# Comprehensive Ingress debugging script
# Usage: ./tools/debug_ingress.sh [method]

set -euo pipefail

METHOD="${1:-ssh}"

# Load .env file if it exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

case "$METHOD" in
    ssh)
        HOST="${2:-${SSH_HOST:-}}"
        SSH_USER="${3:-${SSH_USER:-hassio}}"
        SSH_KEY="${4:-${SSH_KEY:-}}"
        SSH_PASSWORD="${SSH_PASSWORD:-}"
        
        if [ -z "$HOST" ]; then
            echo "Usage: $0 ssh <host> [user] [ssh_key]"
            echo "   OR: Set SSH_HOST, SSH_USER, SSH_KEY, SSH_PASSWORD in .env file"
            echo ""
            echo "Default user: hassio"
            echo "Example: $0 ssh homeassistant.local"
            echo ""
            echo ".env file format:"
            echo "  SSH_HOST=homeassistant.local"
            echo "  SSH_USER=hassio"
            echo "  SSH_PASSWORD=your_password"
            echo "  SSH_KEY=~/.ssh/id_rsa  # optional, if using key auth"
            exit 1
        fi
        
        # Check if we need password authentication
        if [ -n "$SSH_PASSWORD" ]; then
            if command -v sshpass >/dev/null 2>&1; then
                # Use sshpass with proper escaping
                SSH_CMD="sshpass -e ssh"
                export SSHPASS="$SSH_PASSWORD"
                echo "Using password authentication (via sshpass)"
            else
                echo "Warning: sshpass not installed. Install with: brew install hudochenkov/sshpass/sshpass"
                echo "Falling back to interactive password prompt..."
                SSH_CMD="ssh"
            fi
        else
            SSH_CMD="ssh"
        fi
        
        if [ -n "$SSH_KEY" ]; then
            SSH_CMD="$SSH_CMD -i $SSH_KEY"
        fi
        
        # Add options to avoid host key checking issues
        SSH_CMD="$SSH_CMD -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        SSH_CMD="$SSH_CMD $SSH_USER@$HOST"
        
        echo "=== Debugging Ingress on $HOST ==="
        echo ""
        
        # Try to determine if we need sudo for docker commands
        DOCKER_CMD="docker"
        if ! $SSH_CMD "docker ps >/dev/null 2>&1"; then
            echo "Note: Using sudo for docker commands (permission required)"
            DOCKER_CMD="sudo docker"
        fi
        
        # Find container
        echo "1. Finding Dispatcharr container..."
        CONTAINER=$($SSH_CMD "$DOCKER_CMD ps | grep dispatcharr | awk '{print \$1}'" | head -1)
        if [ -z "$CONTAINER" ]; then
            echo "❌ Container not found!"
            echo "Running containers:"
            $SSH_CMD "$DOCKER_CMD ps" 2>&1 | head -10
            echo ""
            echo "Trying alternative method..."
            # Try using ha CLI if available
            if $SSH_CMD "command -v ha >/dev/null 2>&1"; then
                echo "Using Home Assistant CLI..."
                $SSH_CMD "ha addons info dispatcharr" 2>&1 | head -20
            fi
            exit 1
        fi
        echo "✅ Container ID: $CONTAINER"
        echo ""
        
        # Check nginx is running
        echo "2. Checking nginx process..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER ps aux | grep nginx | grep -v grep || echo 'Nginx not running'"
        echo ""
        
        # Check listening ports
        echo "3. Checking listening ports..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER ss -tlnp 2>/dev/null | grep 9191 || $DOCKER_CMD exec $CONTAINER netstat -tlnp 2>/dev/null | grep 9191 || echo 'Port 9191 not found'"
        echo ""
        
        # Check nginx config
        echo "4. Checking nginx configuration..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER cat /etc/nginx/sites-enabled/default | grep -A 5 'listen' | head -10"
        echo ""
        
        # Test nginx config
        echo "5. Testing nginx configuration..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER nginx -t 2>&1"
        echo ""
        
        # Check nginx error logs
        echo "6. Checking nginx error logs (last 20 lines)..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER tail -20 /var/log/nginx/error.log 2>/dev/null || echo 'No error log found'"
        echo ""
        
        # Check nginx access logs
        echo "7. Checking nginx access logs (last 10 lines)..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER tail -10 /var/log/nginx/access.log 2>/dev/null || echo 'No access log found'"
        echo ""
        
        # Test local connection
        echo "8. Testing local connection to nginx..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://localhost:9191/ || echo 'Connection failed'"
        echo ""
        
        # Test from container network
        echo "9. Testing from container network..."
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://0.0.0.0:9191/ || echo 'Connection failed'"
        echo ""
        
        # Check container network
        echo "10. Checking container network configuration..."
        $SSH_CMD "$DOCKER_CMD inspect $CONTAINER | grep -A 20 'NetworkSettings' | head -25"
        echo ""
        
        # Check if Supervisor can reach the container
        echo "11. Checking Supervisor network..."
        SUPERVISOR_IP=$($SSH_CMD "ip route | grep '172.30.32' | head -1 | awk '{print \$1}' | cut -d'/' -f1 || echo '172.30.32.2'")
        echo "Supervisor network: $SUPERVISOR_IP"
        echo ""
        
        # Check Home Assistant logs for ingress errors
        echo "12. Checking Home Assistant logs for ingress errors..."
        if $SSH_CMD "command -v journalctl >/dev/null 2>&1"; then
            $SSH_CMD "sudo journalctl -u hassio-supervisor --no-pager 2>/dev/null | grep -i 'ingress\|dispatcharr' | tail -20 || echo 'No ingress errors found'"
        else
            echo "journalctl not available, trying alternative..."
            $SSH_CMD "ha supervisor logs 2>/dev/null | grep -i 'ingress\|dispatcharr' | tail -20 || echo 'No ingress errors found'"
        fi
        echo ""
        
        # Check if Ingress proxy is running
        echo "13. Checking Ingress proxy status..."
        $SSH_CMD "$DOCKER_CMD ps | grep ingress || echo 'Ingress proxy container not found'"
        echo ""
        
        # Test connection from Supervisor network
        echo "14. Testing connection from Supervisor network to container..."
        CONTAINER_IP=$($SSH_CMD "$DOCKER_CMD inspect $CONTAINER | grep -A 10 'Networks' | grep 'IPAddress' | head -1 | sed 's/.*\"IPAddress\": \"\([^\"]*\)\".*/\1/' || echo ''")
        if [ -n "$CONTAINER_IP" ]; then
            echo "Container IP: $CONTAINER_IP"
            $SSH_CMD "curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' --max-time 5 http://$CONTAINER_IP:9191/ || echo 'Connection failed'"
        else
            echo "Could not determine container IP"
        fi
        echo ""
        
        # Check addon config
        echo "15. Checking addon configuration..."
        $SSH_CMD "sudo cat /data/addons/data/core_config_manager/dispatcharr/config.yaml 2>/dev/null | grep -E 'ingress|port' || echo 'Config not found in expected location'"
        echo ""
        
        # Check recent access attempts
        echo "16. Recent access attempts (last 5):"
        $SSH_CMD "$DOCKER_CMD exec $CONTAINER tail -5 /var/log/nginx/access.log 2>/dev/null || echo 'No access log'"
        echo ""
        
        echo "=== Debugging complete ==="
        echo ""
        echo "Note: If you see 'connection refused' in browser but access logs show requests,"
        echo "      this might be a reverse proxy or Ingress proxy timeout issue."
        echo "      Try accessing directly via Home Assistant's internal network."
        ;;
        
    api)
        HA_URL="${HA_URL:-}"
        HA_TOKEN="${HA_TOKEN:-}"
        
        if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
            echo "Error: HA_URL and HA_TOKEN must be set in .env file"
            exit 1
        fi
        
        HA_URL="${HA_URL%/}"
        
        echo "=== Debugging Ingress via API ==="
        echo ""
        
        # Get addon info
        echo "1. Getting addon information..."
        # Try different slug variations
        for slug in "local/dispatcharr" "dispatcharr"; do
            ADDON_INFO=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
                 -H "Content-Type: application/json" \
                 "$HA_URL/api/hassio/addons/$slug/info" 2>&1)
            
            if echo "$ADDON_INFO" | grep -q '"result":"ok"'; then
                echo "Found addon: $slug"
                echo "$ADDON_INFO" | jq '.data | {name, version, state, ingress, ingress_port, ingress_entry}' 2>/dev/null || echo "$ADDON_INFO"
                break
            fi
        done
        echo ""
        
        # Get addon logs
        echo "2. Getting recent addon logs..."
        for slug in "local/dispatcharr" "dispatcharr"; do
            ADDON_LOGS=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
                 -H "Content-Type: application/json" \
                 "$HA_URL/api/hassio/addons/$slug/logs" 2>&1)
            
            if echo "$ADDON_LOGS" | grep -q '"result":"ok"'; then
                echo "$ADDON_LOGS" | jq -r '.data' 2>/dev/null | tail -30 || echo "$ADDON_LOGS"
                break
            fi
        done
        echo ""
        
        # Get supervisor logs
        echo "3. Getting supervisor logs (ingress related)..."
        SUPERVISOR_LOGS=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
             -H "Content-Type: application/json" \
             "$HA_URL/api/hassio/supervisor/logs" 2>&1)
        
        echo "$SUPERVISOR_LOGS" | grep -i "ingress\|dispatcharr" | tail -20 || echo "No ingress-related logs found"
        echo ""
        ;;
        
    docker)
        echo "=== Debugging Ingress via Docker ==="
        echo ""
        
        CONTAINER=$(docker ps | grep dispatcharr | awk '{print $1}' | head -1)
        if [ -z "$CONTAINER" ]; then
            echo "❌ Container not found!"
            exit 1
        fi
        
        echo "Container ID: $CONTAINER"
        echo ""
        
        echo "1. Nginx listening ports:"
        docker exec $CONTAINER ss -tlnp 2>/dev/null | grep 9191 || docker exec $CONTAINER netstat -tlnp 2>/dev/null | grep 9191
        echo ""
        
        echo "2. Nginx config:"
        docker exec $CONTAINER grep -A 3 "listen" /etc/nginx/sites-enabled/default | head -5
        echo ""
        
        echo "3. Testing local connection:"
        docker exec $CONTAINER curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:9191/ || echo "Failed"
        echo ""
        
        echo "4. Nginx error log (last 10 lines):"
        docker exec $CONTAINER tail -10 /var/log/nginx/error.log 2>/dev/null || echo "No error log"
        echo ""
        ;;
        
    *)
        echo "Usage: $0 [ssh|api|docker] [options]"
        echo ""
        echo "Methods:"
        echo "  ssh    - Debug via SSH (requires SSH access)"
        echo "  api    - Debug via Home Assistant API (uses .env)"
        echo "  docker - Debug via direct Docker access"
        exit 1
        ;;
esac

