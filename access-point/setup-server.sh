#!/bin/sh
#
# Registers the captive portal as a system service.
# Called by setup.py after it has resolved the project path.
#
# Set ADMIN_SECRET below to a long, hard-to-guess string before running.
# The admin URL will be:  http://splines.portal/admin/disable?token=<ADMIN_SECRET>

# --- Set your static admin secret here -------------------------------------
ADMIN_SECRET="happy-birthday"
# ---------------------------------------------------------------------------

set -e

# --- Deploy restore script --------------------------------------------------
# setup.py already copied the lighttpd config; we copy the restore script here
# so it lives at a stable system path the CGI can reference unconditionally.
sudo cp ./restore-network.sh /usr/local/bin/portal-restore-network.sh
sudo chmod +x /usr/local/bin/portal-restore-network.sh

# --- sudoers rule -----------------------------------------------------------
# Allows the www-data user (lighttpd's process owner) to run the restore
# script as root without a password prompt (needed from CGI context).
echo "www-data ALL=(ALL) NOPASSWD: /usr/local/bin/portal-restore-network.sh" \
    | sudo tee /etc/sudoers.d/portal-restore > /dev/null
sudo chmod 440 /etc/sudoers.d/portal-restore

# --- Admin token ------------------------------------------------------------
if [ "$ADMIN_SECRET" = "happy-birthday" ]; then
    echo "❌  Error: ADMIN_SECRET is still set to the default placeholder."
    echo "   Edit setup-server.sh and set ADMIN_SECRET to a secret string before running."
    exit 1
fi
echo "$ADMIN_SECRET" | sudo tee /etc/portal-admin-token > /dev/null
# www-data needs to read this file to validate incoming requests
sudo chmod 644 /etc/portal-admin-token

# --- Enable and start lighttpd ----------------------------------------------
sudo systemctl enable lighttpd
sudo systemctl restart lighttpd

# --- Done -------------------------------------------------------------------
echo ""
echo "✅  Captive portal server is up."
echo ""
echo "🔑  Admin URL to switch back to normal mode:"
echo "    http://splines.portal/admin/disable?token=$ADMIN_SECRET"
echo ""
