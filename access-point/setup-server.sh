#!/bin/sh
#
# Registers the captive portal as a system service and generates
# the admin secret token used to disable the portal remotely.
# Called by setup.py after it has resolved the project path.

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
ADMIN_TOKEN=$(openssl rand -hex 16)
echo "$ADMIN_TOKEN" | sudo tee /etc/portal-admin-token > /dev/null
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
echo "    http://splines.portal/admin/disable?token=$ADMIN_TOKEN"
echo ""
echo "    ⚠  Save this URL now — you will need it to regain SSH access"
echo "       if the Pi is no longer reachable on the home network."
echo ""
