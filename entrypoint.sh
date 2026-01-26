#!/bin/bash
# Clawdbot Gateway Entrypoint
# This script ensures the gateway can start with proper configuration

set -e

# If no gateway token is set, generate one automatically
if [ -z "$CLAWDBOT_GATEWAY_TOKEN" ]; then
    export CLAWDBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
    echo "Generated gateway token: $CLAWDBOT_GATEWAY_TOKEN"
    echo "Save this token to access the Control UI!"
fi

# Build trusted proxies JSON array from environment variable
# Default includes common Docker gateway IPs
DEFAULT_PROXIES="10.0.0.1,10.0.1.1,10.0.1.2,10.0.2.1,10.0.2.2,10.0.3.1,10.0.3.2,10.0.4.1,172.17.0.1,172.18.0.1,127.0.0.1"
TRUSTED_PROXIES=${CLAWDBOT_TRUSTED_PROXIES:-$DEFAULT_PROXIES}

# Convert comma-separated list to JSON array
PROXIES_JSON=$(echo "$TRUSTED_PROXIES" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
echo "Trusted proxies: $PROXIES_JSON"

# Create config directory if it doesn't exist
mkdir -p /data/.clawdbot

# Always create/update config to ensure gateway.mode is set
# (Previous configs may be missing required fields)
cat > /data/.clawdbot/clawdbot.json << EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${CLAWDBOT_GATEWAY_TOKEN}"
    },
    "trustedProxies": ${PROXIES_JSON}
  },
  "agents": {
    "defaults": {
      "workspace": "/data/clawd"
    }
  }
}
EOF
echo "Config written to /data/.clawdbot/clawdbot.json"

# Start the gateway with --allow-unconfigured flag as fallback
exec node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured
