#!/usr/bin/env bash
set -euo pipefail

# Verifies port availability for lan-dns (port 53) and name-proxy (port 80) on macOS.
#
# Docker Desktop on macOS publishes ports directly on the host interface.
# The macOS application firewall operates at the application layer and
# Docker Desktop registers its own rules — no manual rules are needed.
#
# If you use a third-party firewall (Little Snitch, Lulu, etc.), add inbound
# rules manually to allow:
#   UDP/TCP port 53 from your LAN subnet
#   TCP port 80 from your LAN subnet

echo "Checking what is listening on ports 53 and 80..."
sudo lsof -iTCP:80 -iUDP:53 -iTCP:53 -n -P | grep LISTEN || true

echo ""
echo "If Docker Desktop is running, the above should show entries for com.docker."
echo "No manual firewall changes are needed unless you use a third-party firewall."
