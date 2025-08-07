#!/bin/bash

# Configuration des règles iptables pour le pare-feu
# Ces commandes sont à exécuter sur la machine firewall

# Variables réseau
WAN="19.4.3.16/29"
LAN="19.4.3.0/29"
DMZ="19.4.3.8/29"

# Variables de services
HTTP="80"
HTTPS="443"
SSH="22"

# Variables d'interfaces
WAN_IFACE="eth0"
LAN_IFACE="eth1"
DMZ_IFACE="eth2"

# Autoriser HTTP, HTTPS, SSH vers la DMZ (depuis WAN et LAN)
iptables -A FORWARD -p tcp -s $LAN,$WAN -d $DMZ -m multiport --dports $HTTP,$HTTPS,$SSH -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $DMZ -d $LAN,$WAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser le LAN à sortir vers l'extérieur via NAT
iptables -t nat -A POSTROUTING -s $LAN -o $WAN_IFACE -j MASQUERADE
iptables -A FORWARD -s $LAN -o $WAN_IFACE -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $WAN -i $WAN_IFACE -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Redirection du trafic HTTP vers le proxy Squid
iptables -t nat -A PREROUTING -i $LAN_IFACE -p tcp --dport 80 -j REDIRECT --to-port 3128

# Limitation de bande passante pour le LAN
iptables -A FORWARD -s $LAN -o $WAN_IFACE -m hashlimit --hashlimit-name lan_upload --hashlimit-mode srcip --hashlimit-above 500kb/s -j DROP
iptables -A FORWARD -d $LAN -i $WAN_IFACE -m hashlimit --hashlimit-name lan_download --hashlimit-mode dstip --hashlimit-above 500kb/s -j DROP

# Autorisation du loopback et connexions établies pour l'interface INPUT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Afficher les règles configurées
echo -e "\nRègles iptables configurées :"
iptables -L -v
echo -e "\nRègles NAT configurées :"
iptables -t nat -L -v
