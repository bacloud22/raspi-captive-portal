#!/bin/sh
#
# Restores normal networking after captive portal mode.
# Called by the admin endpoint CGI script (via sudo).
# Run this directly if you prefer: sudo ./access-point/restore-network.sh
#
# What this undoes:
#   - Stops and disables hostapd (access point)
#   - Stops and disables dnsmasq (DNS/DHCP hijack)
#   - Restores /etc/dhcpcd.conf from the backup made by setup-access-point.sh
#   - Restores /etc/dnsmasq.conf from its backup (if present)
#   - Removes the iptables PREROUTING rule (if it still exists)
#   - Restarts dhcpcd so the Pi reconnects to the home router

set -e

echo "==> Stopping access point (hostapd)..."
systemctl stop hostapd  || true
systemctl disable hostapd || true

echo "==> Stopping DNS/DHCP server (dnsmasq)..."
systemctl stop dnsmasq  || true
systemctl disable dnsmasq || true

echo "==> Restoring dhcpcd config..."
if [ -f /etc/dhcpcd.conf.orig ]; then
    cp /etc/dhcpcd.conf.orig /etc/dhcpcd.conf
    echo "    /etc/dhcpcd.conf restored from backup."
else
    echo "    WARNING: no backup found at /etc/dhcpcd.conf.orig — skipping."
fi

echo "==> Restoring dnsmasq config..."
if [ -f /etc/dnsmasq.conf.orig ]; then
    cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
    echo "    /etc/dnsmasq.conf restored from backup."
fi

echo "==> Removing iptables NAT rule (if present)..."
iptables -t nat -D PREROUTING -p tcp --dport 80 -j DNAT \
    --to-destination 192.168.4.1:3000 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

echo "==> Rebooting to cleanly rejoin home network..."
# A reboot is the most reliable way to release the wlan interface from AP mode
# and let wpa_supplicant/NetworkManager reconnect to the known WiFi.
# hostapd and dnsmasq are already disabled above, so the captive portal will
# NOT restart — the Pi will boot straight into normal networking mode.
reboot
