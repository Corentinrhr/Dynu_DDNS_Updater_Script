# Dynu DDNS Updater Script
A simple Dynu DDNS updater script with optional Telegram notifications for IPv4 and IPv6 changes. Designed to run on Linux or inside a Docker container.

---

## Features
* Checks your public IPv4 and IPv6 addresses.
* Updates Dynu DDNS if your IP has changed.
* Sends Telegram notifications on success or failure (optional).
* Caches previous IPs to avoid unnecessary updates.
* Compatible with IPv6 EUI-64 addressing.

---

## Requirements
* Bash (`#!/bin/bash`)
* `curl`
* Dynu account with username, password (SHA256 hashed), and hostname group.
* **Optional**: Telegram bot token and chat ID for alerts.

---

## Setup

1.  Clone or copy the script and the `.env` file.
2.  Edit `ddns_update.env` with your details:
    ```shell
    # Dynu Credentials
    DYNU_USERNAME="your_username"
    DYNU_PASSWORD="your_sha256_password"
    DYNU_GROUP="your_host_group"

    # For IPv6 EUI-64. Get this from your router's LAN settings.
    ROUTER_IPV6_HOST_PART="last_64_bits_of_your_router_ipv6"

    # Optional: Telegram Notifications
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""

    # System Settings
    TIMEZONE="Europe/Paris"
    CACHE_FILE_V4="/ddns/ip_cache_v4.txt"
    CACHE_FILE_V6="/ddns/ip_cache_v6.txt"
    ```
    **Note:** Make sure the file uses Unix (LF) line endings.

3.  Make the script executable:
    ```bash
    chmod +x ddns_update.sh
    ```

4.  Run the script manually to test:
    ```bash
    ./ddns_update.sh
    ```

---

## Automation
To run the script periodically, you can use `cron` or Docker.

### Cron
Add the following line to your crontab to run the script every 5 minutes and log its output.

```bash
# Example: run every 5 minutes
*/5 * * * * /path/to/ddns_update.sh >> /var/log/ddns_update.log 2>&1
```

## Logging & Cache
Logs include timestamps based on the TIMEZONE variable.
The most recently known public IPs are stored in the files specified by CACHE_FILE_V4 and CACHE_FILE_V6.
If the current public IP matches the cached IP, the script will exit early to avoid unnecessary API calls to Dynu.

## Telegram Notifications (Optional)
If TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are set in the .env file, the script will:
Send a success message whenever your Dynu DNS record is updated.
Send an error message if the update fails for any reason.
