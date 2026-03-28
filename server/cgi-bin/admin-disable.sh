#!/bin/sh
#
# Admin endpoint: disables the captive portal and restores normal networking.
#
# GET  /admin/disable?token=TOKEN  → confirmation page
# POST /admin/disable?token=TOKEN  → restore network, show "disconnecting" page
#
# The token is stored at /etc/portal-admin-token (written by setup-server.sh).
# The restore script is at /usr/local/bin/portal-restore-network.sh.
# www-data is allowed to sudo that specific script (see /etc/sudoers.d/portal-restore).

TOKEN_FILE="/etc/portal-admin-token"
RESTORE_SCRIPT="/usr/local/bin/portal-restore-network.sh"

# --- Validate token ---------------------------------------------------------

STORED_TOKEN=""
if [ -f "$TOKEN_FILE" ]; then
    STORED_TOKEN=$(cat "$TOKEN_FILE")
fi

# QUERY_STRING looks like "token=abc123" or "foo=bar&token=abc123"
REQUEST_TOKEN=$(printf "%s" "$QUERY_STRING" | sed -n 's/.*[&]token=\([^&]*\).*/\1/p')
# Handle the simple case where token= is the first (or only) param
if [ -z "$REQUEST_TOKEN" ]; then
    REQUEST_TOKEN=$(printf "%s" "$QUERY_STRING" | sed -n 's/^token=\([^&]*\).*/\1/p')
fi

if [ -z "$STORED_TOKEN" ] || [ "$REQUEST_TOKEN" != "$STORED_TOKEN" ]; then
    printf "Status: 403 Forbidden\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "\r\n"
    printf "Forbidden\n"
    exit 0
fi

# --- Handle GET: show confirmation form -------------------------------------

if [ "$REQUEST_METHOD" = "GET" ]; then
    printf "Content-Type: text/html\r\n"
    printf "\r\n"
    cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Disable Captive Portal</title>
  <style>
    body { font-family: sans-serif; max-width: 480px; margin: 3rem auto; padding: 0 1rem; }
    button { padding: .6rem 1.4rem; font-size: 1rem; cursor: pointer; }
  </style>
</head>
<body>
  <h2>Disable Captive Portal</h2>
  <p>This will stop the access point (hostapd &amp; dnsmasq), restore the original
  network configuration, and reconnect the Pi to the home network.</p>
  <p><strong>You will be disconnected from this WiFi immediately after confirming.</strong></p>
  <form method="post" action="/admin/disable?token=${REQUEST_TOKEN}">
    <button type="submit">Confirm: switch back to normal mode</button>
  </form>
</body>
</html>
HTML

# --- Handle POST: restore network -------------------------------------------

elif [ "$REQUEST_METHOD" = "POST" ]; then
    printf "Content-Type: text/html\r\n"
    printf "\r\n"
    cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Restoring…</title>
</head>
<body>
  <h2>Restoring normal network mode…</h2>
  <p>The Pi will disconnect from AP mode in a moment.</p>
  <p>Reconnect to your home WiFi, then SSH into the Pi as usual.</p>
</body>
</html>
HTML

    # setsid detaches from the current session/cgroup so the restore process
    # survives after lighttpd's CGI handler exits.
    # The 2-second sleep gives the browser time to receive the response above.
    setsid sh -c "sleep 2 && sudo $RESTORE_SCRIPT" > /dev/null 2>&1 &

else
    printf "Status: 405 Method Not Allowed\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "\r\n"
    printf "Method Not Allowed\n"
fi
