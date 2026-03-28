  ---
  Lighttpd replaces Node.js/Express:
  - lighttpd/lighttpd.conf — declares mod_cgi, mod_alias, mod_redirect; serves server/public/ statically; does the captive portal hostname redirect; maps /api/ping and /admin/disable to
  CGI scripts
  - No iptables DNAT rule needed (Lighttpd binds port 80 directly)

  Admin endpoint:
  - server/cgi-bin/admin-disable.sh — GET shows a confirmation page, POST triggers restore
  - URL: http://splines.portal/admin/disable?token=<generated-token>
  - Response is sent first, then setsid detaches the restore call (with a 2s delay) so the browser receives the page before the network drops

  Restore script:
  - access-point/restore-network.sh — stops hostapd + dnsmasq, copies back /etc/dhcpcd.conf.orig, removes the old iptables rule if present, restarts dhcpcd so the Pi rejoins home WiFi
  - Copied to /usr/local/bin/portal-restore-network.sh during setup; www-data (lighttpd's user) is granted passwordless sudo for just that one script

  Setup changes:
  - setup-access-point.sh — now backs up /etc/dhcpcd.conf before appending to it
  - setup-server.sh — generates a 32-char hex token with openssl rand, saves it to /etc/portal-admin-token, configures sudoers, starts lighttpd; prints the admin URL clearly at the end —
  save it before the Pi disconnects
  - setup.py — removed all Node.js/npm/TypeScript steps; added install_lighttpd() and updated setup_server_service() to substitute the project path in the config