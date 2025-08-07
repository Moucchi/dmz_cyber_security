#!/bin/bash

# Configuration des adresses IP pour les différentes machines virtuelles

# Configuration LAN - internal-desktop
ip a add 19.4.3.1/29 dev eth0
ip route add default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf

# Configuration LAN - internal-server
ip a add 19.4.3.2/29 dev eth0
ip route add default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf

# Configuration WAN - internet
ip a add 19.4.3.17/29 dev eth0
ip route add default via 19.4.3.18 dev eth0

# Configuration DMZ - public-server
ip a add 19.4.3.9/29 dev eth0
ip route add default via 19.4.3.11 dev eth0

# Configuration pare-feu
ip a add 19.4.3.3/29 dev eth1
ip a add 19.4.3.11/29 dev eth2
ip a add 19.4.3.18/29 dev eth0
sysctl -w net.ipv4.ip_forward=1
