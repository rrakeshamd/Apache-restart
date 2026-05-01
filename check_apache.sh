#!/bin/bash
# Apache health check — restarts apache2 if it doesn't respond
# Usage: sudo ./check_apache.sh
# Cron (every 5 min): */5 * * * * /home/rrakesh/Apache-restart/check_apache.sh

URL="http://localhost"
TIMEOUT=10
SERVICE="apache2"
LOG_FILE="/var/log/apache_check.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

HTTP_CODE=$(curl --silent --max-time "$TIMEOUT" \
                 --output /dev/null \
                 --write-out "%{http_code}" \
                 "$URL")

if [ "$HTTP_CODE" = "000" ] || [ -z "$HTTP_CODE" ]; then
    log "ALERT: Apache not responding (HTTP $HTTP_CODE). Restarting $SERVICE..."
    if systemctl restart "$SERVICE"; then
        log "INFO: $SERVICE restarted successfully."
    else
        log "ERROR: Failed to restart $SERVICE. Check service status."
        exit 1
    fi
else
    log "OK: Apache responding (HTTP $HTTP_CODE)."
fi
