#!/usr/bin/env bash
set -euo pipefail

# Opens ufw firewall rules for lan-dns (port 53) and name-proxy (port 80).
# Usage: ./open-firewall-linux.sh <subnet>
# Example: ./open-firewall-linux.sh 192.168.1.0/24

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <subnet>"
  echo ""
  echo "Find your LAN subnet:"
  echo "  ip route | grep src | head -5"
  exit 1
fi

SUBNET="$1"

sudo ufw allow from "$SUBNET" to any port 53 proto udp
sudo ufw allow from "$SUBNET" to any port 53 proto tcp
sudo ufw allow from "$SUBNET" to any port 80 proto tcp
sudo ufw reload

echo "Firewall rules applied for subnet $SUBNET"
