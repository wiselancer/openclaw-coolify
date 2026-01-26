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
    "trustedProxies": ${PROXIES_JSON},
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/data/clawd"
    }
  }
}
EOF
echo "Config written to /data/.clawdbot/clawdbot.json"

# Create auth-profiles.json for API keys / OAuth tokens
AUTH_DIR="/data/.clawdbot/agents/main/agent"
mkdir -p "$AUTH_DIR"

# Build auth profiles from environment variables
AUTH_PROFILES="{}"

# Add Anthropic API key if provided
if [ -n "$ANTHROPIC_API_KEY" ]; then
    AUTH_PROFILES=$(echo "$AUTH_PROFILES" | jq --arg key "$ANTHROPIC_API_KEY" '. + {"anthropic:api": {"provider": "anthropic", "mode": "api_key", "apiKey": $key}}')
    echo "Added Anthropic API key to auth profiles"
fi

# Add Claude OAuth token if provided (from claude setup-token)
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    AUTH_PROFILES=$(echo "$AUTH_PROFILES" | jq --arg token "$CLAUDE_CODE_OAUTH_TOKEN" '. + {"anthropic:claude-cli": {"provider": "anthropic", "mode": "oauth", "accessToken": $token}}')
    echo "Added Claude OAuth token to auth profiles"
fi

# Add OpenAI API key if provided
if [ -n "$OPENAI_API_KEY" ]; then
    AUTH_PROFILES=$(echo "$AUTH_PROFILES" | jq --arg key "$OPENAI_API_KEY" '. + {"openai:api": {"provider": "openai", "mode": "api_key", "apiKey": $key}}')
    echo "Added OpenAI API key to auth profiles"
fi

# Add OpenRouter API key if provided
if [ -n "$OPENROUTER_API_KEY" ]; then
    AUTH_PROFILES=$(echo "$AUTH_PROFILES" | jq --arg key "$OPENROUTER_API_KEY" '. + {"openrouter:api": {"provider": "openrouter", "mode": "api_key", "apiKey": $key}}')
    echo "Added OpenRouter API key to auth profiles"
fi

# Add Gemini API key if provided
if [ -n "$GEMINI_API_KEY" ]; then
    AUTH_PROFILES=$(echo "$AUTH_PROFILES" | jq --arg key "$GEMINI_API_KEY" '. + {"google:api": {"provider": "google", "mode": "api_key", "apiKey": $key}}')
    echo "Added Gemini API key to auth profiles"
fi

# Write auth profiles if any keys were added
if [ "$AUTH_PROFILES" != "{}" ]; then
    echo "$AUTH_PROFILES" > "$AUTH_DIR/auth-profiles.json"
    echo "Auth profiles written to $AUTH_DIR/auth-profiles.json"
else
    echo "Warning: No API keys or OAuth tokens configured. Add ANTHROPIC_API_KEY, OPENAI_API_KEY, or CLAUDE_CODE_OAUTH_TOKEN to environment variables."
fi

# Start the gateway with --allow-unconfigured flag as fallback
exec node dist/index.js gateway --bind lan --port 18789 --allow-unconfigured
