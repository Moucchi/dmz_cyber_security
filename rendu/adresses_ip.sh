#!/bin/bash

# Configuration des adresses IP pour les différentes machines virtuelles
# Ce script configure l'adressage IP pour chaque machine de notre infrastructure DMZ

# ==========================================================================
# JUSTIFICATION DE L'ARCHITECTURE RÉSEAU:
# - Utilisation de sous-réseaux /29 (8 adresses) pour optimiser l'espace d'adressage
# - Séparation en 3 zones distinctes (LAN, DMZ, WAN) pour une meilleure isolation
# - Chaque zone utilise un sous-réseau différent pour faciliter les règles de filtrage
# ==========================================================================

# Configuration LAN - internal-desktop
# L'adresse 19.4.3.1 est attribuée au poste de travail interne
# La passerelle par défaut pointe vers l'interface LAN du pare-feu (19.4.3.3)
# Le serveur DNS est configuré pour utiliser le service DNSmasq du pare-feu
ip a add 19.4.3.1/29 dev eth0
ip route add default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf

# Configuration LAN - internal-server
# L'adresse 19.4.3.2 est attribuée au serveur interne
# Configuration similaire à internal-desktop pour la cohérence du réseau
# Ce serveur héberge des services accessibles uniquement depuis le LAN
ip a add 19.4.3.2/29 dev eth0
ip route add default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf

# Configuration WAN - internet
# Cette machine simule un serveur externe sur Internet
# L'adresse 19.4.3.17 permet de tester la connectivité sortante du réseau
# Dans un environnement réel, cette machine serait remplacée par une connexion Internet
ip a add 19.4.3.17/29 dev eth0
ip route add default via 19.4.3.18 dev eth0

# Configuration DMZ - public-server
# L'adresse 19.4.3.9 est attribuée au serveur public dans la DMZ
# Ce serveur est accessible depuis Internet mais contrôlé par le pare-feu
# La passerelle pointe vers l'interface DMZ du pare-feu (19.4.3.11)
# Cette configuration permet une exposition contrôlée des services publics
ip a add 19.4.3.9/29 dev eth0
ip route add default via 19.4.3.11 dev eth0

# Configuration pare-feu
# Le pare-feu possède 3 interfaces réseau, une pour chaque zone:
# - eth1 (19.4.3.3/29): Interface LAN pour le réseau interne
# - eth2 (19.4.3.11/29): Interface DMZ pour les serveurs publics
# - eth0 (19.4.3.18/29): Interface WAN pour la connexion Internet
# Cette configuration "three-legged" est optimale pour la sécurisation d'une DMZ
# car elle permet un contrôle granulaire des flux entre chaque zone
ip a add 19.4.3.3/29 dev eth1
ip a add 19.4.3.11/29 dev eth2
ip a add 19.4.3.18/29 dev eth0
# Activation du routage IP - nécessaire pour que le pare-feu transmette les paquets entre interfaces
sysctl -w net.ipv4.ip_forward=1
