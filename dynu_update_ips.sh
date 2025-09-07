#!/bin/bash

# ###############################################
# Dynu DDNS Update Script (with Telegram alerts)
# ###############################################

# --- SCRIPT SETUP ---
SCRIPT_DIR="$(dirname "$0")"
ENV_FILE="${SCRIPT_DIR}/ddns_update.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "[ERROR] Configuration file not found at '$ENV_FILE'."
    echo "Please create it from the example."
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

# --- Functions ---
log() {
    echo "[$(TZ=$TIMEZONE date '+%Y-%m-%d %H:%M:%S %Z')] $1"
}

send_telegram() {
    local message="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
             -d chat_id="${TELEGRAM_CHAT_ID}" \
             -d text="$message" \
             -d parse_mode="Markdown" > /dev/null
    else
        log "ℹ️ Telegram notifications are disabled (token or chat ID not set)."
    fi
}

# --- Start of Script ---
log "📶 Starting DDNS check (IPv4 & IPv6)..."

# Ensure cache directory exists
CACHE_DIR=$(dirname "$CACHE_FILE_V4")
if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
    log "📁 Created cache directory: $CACHE_DIR"
fi

# Read old IPs from cache files
OLD_IPV4="" && [ -f "$CACHE_FILE_V4" ] && OLD_IPV4=$(cat "$CACHE_FILE_V4")
OLD_IPV6="" && [ -f "$CACHE_FILE_V6" ] && OLD_IPV6=$(cat "$CACHE_FILE_V6")

# Get current public IPs
CURRENT_IPV4=$(curl -s "https://api.ipify.org")
DEVICE_IPV6_ADDRESS=$(curl -s "https://api6.ipify.org")

# Construct the full router IPv6 address from the public prefix
if [ -z "$DEVICE_IPV6_ADDRESS" ]; then
    log "⚠️ Warning: Could not retrieve the public IPv6 address."
    CURRENT_ROUTER_IPV6="no"
else
    IPV6_NETWORK_PREFIX=$(echo "$DEVICE_IPV6_ADDRESS" | cut -d ':' -f1-4)
    CURRENT_ROUTER_IPV6="${IPV6_NETWORK_PREFIX}:${ROUTER_IPV6_HOST_PART}"
fi

# Compare old and new IPs
if [ "$CURRENT_IPV4" == "$OLD_IPV4" ] && [ "$CURRENT_ROUTER_IPV6" == "$OLD_IPV6" ]; then
    log "✅ IP addresses have not changed (IPv4: $CURRENT_IPV4, IPv6: $CURRENT_ROUTER_IPV6). No action required."
    exit 0
fi

log "⚠️ IP change detected!"
log "Old IPv4: '$OLD_IPV4' -> New: '$CURRENT_IPV4'"
log "Old IPv6: '$OLD_IPV6' -> New: '$CURRENT_ROUTER_IPV6'"
log "Update required..."

# Build the Dynu update URL
UPDATE_URL="https://api.dynu.com/nic/update?username=${DYNU_USERNAME}&group=${DYNU_GROUP}&myip=${CURRENT_IPV4}&myipv6=${CURRENT_ROUTER_IPV6}&password=${DYNU_PASSWORD}"

log "Sending update request to Dynu..."
RESPONSE=$(curl -s "$UPDATE_URL")
log "Dynu API Response: $RESPONSE"

# Process Dynu's response
if [[ "$RESPONSE" == good* || "$RESPONSE" == nochg* ]]; then
    log "🎉 Update successful. Response: $RESPONSE"
    MESSAGE="🔄 *Dynu DDNS Updated*"
    MESSAGE+=$'\n'"Group: *${DYNU_GROUP}*"
    MESSAGE+=$'\n'"IPv4: \`${CURRENT_IPV4}\`"
    MESSAGE+=$'\n'"IPv6: \`${CURRENT_ROUTER_IPV6}\`"
    send_telegram "$MESSAGE"

    echo "$CURRENT_IPV4" > "$CACHE_FILE_V4"
    echo "$CURRENT_ROUTER_IPV6" > "$CACHE_FILE_V6"
    exit 0
else
    log "❌ Error: The update failed."
    send_telegram "❌ *Dynu DDNS Error*\nGroup: *${DYNU_GROUP}*\nResponse: \`${RESPONSE}\`"
    exit 1
fi
