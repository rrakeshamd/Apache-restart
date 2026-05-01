# Apache-restart

A bash script that monitors Apache and automatically restarts it if it stops responding.

## What it does

- Sends an HTTP request to `http://localhost` with a 10-second timeout
- If Apache responds with any HTTP code, logs `OK` and exits
- If Apache does not respond (HTTP code `000` or empty), it:
  - Logs an alert
  - Runs `systemctl restart apache2`
  - Logs success or failure of the restart
- All events are appended to `/var/log/apache_check.log` with timestamps

## Usage

```bash
sudo ./check_apache.sh
```

## Cron setup (every 5 minutes)

```
*/5 * * * * /home/rrakesh/Apache-restart/check_apache.sh
```

## Requirements

- `curl` installed
- `systemctl` (systemd-based Linux)
- Must run as root or a user with permission to restart `apache2`
