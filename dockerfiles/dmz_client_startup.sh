#!/usr/bin/env bash
set -euo pipefail

# Config réseau dmz_client
ip addr replace 19.4.3.1/29 dev eth0
ip route replace default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf

exec "$@"