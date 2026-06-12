#!/bin/bash
# Apache health check — restarts apache2 if it doesn't respond
# Usage: sudo ./check_apache.sh
# Cron (every 5 min): */5 * * * * /home/rrakesh/Apache-restart/check_apache.sh

URL="http://localhost"
TIMEOUT=10
LOG_FILE="/var/log/apache_check.log"
MAIL_TO="rrakesh@amd.com"
HOSTNAME=$(hostname)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

cleanup_semaphores() {
    local sems
    sems=$(ipcs -s | awk 'NR>2 && $2 ~ /^[0-9]+$/ {print $2}')
    if [ -n "$sems" ]; then
        log "INFO: Cleaning up stale IPC semaphores..."
        for i in $sems; do
            ipcrm sem "$i" 2>/dev/null && log "INFO: Removed semaphore $i"
        done
    else
        log "INFO: No stale IPC semaphores found."
    fi
}

HTTP_CODE=$(curl --silent --max-time "$TIMEOUT" \
                 --output /dev/null \
                 --write-out "%{http_code}" \
                 "$URL")

if [ "$HTTP_CODE" = "000" ] || [ -z "$HTTP_CODE" ]; then
    log "ALERT: Apache not responding (HTTP $HTTP_CODE)."

    SYNTAX_CHECK=$(/usr/sbin/httpd -t 2>&1)
    if [ $? -ne 0 ]; then
        log "ERROR: Apache config syntax check failed. Skipping restart."
        log "ERROR: $SYNTAX_CHECK"
        echo "Apache on $HOSTNAME is down and cannot be restarted due to a config error.

$SYNTAX_CHECK

Fix the config and manually start httpd." \
            | mail -s "[CRITICAL] Apache config error on $HOSTNAME" "$MAIL_TO"
        exit 1
    fi

    if ps -ef | grep httpd | grep -v grep > /dev/null 2>&1; then
        log "INFO: httpd process still running but port not responding. Killing stale process..."
        pkill -9 httpd
        sleep 2
        cleanup_semaphores
        log "INFO: Starting httpd..."
        if /etc/init.d/httpd start; then
            log "INFO: httpd started successfully."
            echo "Apache on $HOSTNAME was unresponsive with stale httpd process. Process was killed and httpd started successfully at $(date)." \
                | mail -s "[ALERT] Apache restarted on $HOSTNAME" "$MAIL_TO"
        else
            log "ERROR: Failed to start httpd. Check service status."
            echo "Apache on $HOSTNAME was unresponsive with stale httpd process. Process was killed but httpd FAILED to start at $(date). Manual intervention required." \
                | mail -s "[CRITICAL] Apache failed to start on $HOSTNAME" "$MAIL_TO"
            exit 1
        fi
    else
        log "INFO: Restarting httpd..."
        cleanup_semaphores
        if /etc/init.d/httpd restart; then
            log "INFO: httpd restarted successfully."
            echo "Apache on $HOSTNAME was unresponsive (no running process). httpd restarted successfully at $(date)." \
                | mail -s "[ALERT] Apache restarted on $HOSTNAME" "$MAIL_TO"
        else
            log "ERROR: Failed to restart httpd. Check service status."
            echo "Apache on $HOSTNAME was unresponsive and httpd FAILED to restart at $(date). Manual intervention required." \
                | mail -s "[CRITICAL] Apache failed to restart on $HOSTNAME" "$MAIL_TO"
            exit 1
        fi
    fi
else
    log "OK: Apache responding (HTTP $HTTP_CODE)."
fi
