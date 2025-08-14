#!/bin/bash

# Configuration des règles iptables pour le pare-feu
# Ces commandes sont à exécuter sur la machine firewall

# =====================================================================
# JUSTIFICATION DE LA STRATÉGIE DE SÉCURITÉ:
# - Application du principe de moindre privilège: autoriser uniquement le trafic nécessaire
# - Segmentation réseau stricte entre LAN, DMZ et WAN
# - Protection du réseau interne tout en permettant l'hébergement de services publics
# - Contrôle du trafic sortant et entrant pour prévenir les exfiltrations de données
# =====================================================================

# Variables réseau
# Définition des plages d'adresses pour chaque zone
# Ces variables facilitent la maintenance et la lisibilité des règles
WAN="19.4.3.16/29"  # Zone Internet/externe
LAN="19.4.3.0/29"   # Zone réseau local/interne
DMZ="19.4.3.8/29"   # Zone démilitarisée pour les serveurs accessibles publiquement

# Variables de services
# Définition des ports standards pour les services autorisés
# L'utilisation de variables symboliques améliore la lisibilité et facilite les modifications
HTTP="80"    # Port standard pour le service web HTTP
HTTPS="443"  # Port standard pour le service web HTTPS sécurisé
SSH="22"     # Port standard pour l'administration à distance sécurisée

# Variables d'interfaces
# Association des interfaces physiques à leur rôle logique
# Cette abstraction permet de modifier facilement l'architecture physique sans changer la logique des règles
WAN_IFACE="eth0"   # Interface connectée à Internet
LAN_IFACE="eth1"   # Interface connectée au réseau interne
DMZ_IFACE="eth2"   # Interface connectée à la DMZ

# Autoriser HTTP, HTTPS, SSH vers la DMZ (depuis WAN et LAN)
# - L'accès est limité uniquement aux protocoles spécifiques (HTTP, HTTPS, SSH)
# - La première règle autorise les nouvelles connexions entrantes vers la DMZ
# - La seconde règle autorise uniquement le trafic de retour pour les connexions déjà établies
iptables -A FORWARD -p tcp -s $LAN,$WAN -d $DMZ -m multiport --dports $HTTP,$HTTPS,$SSH -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $DMZ -d $LAN,$WAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Bloquer toute autre port ou protocole par defaut
# - Change le comportement par defaut à adopter si la requette ne correspond à aucune règle
iptables -P FORWARD DROP

# Bloquer l’accès du WAN vers le LAN
# - Le trafic est bloqué pour toutes les nouvelles connexions mais est autorisé pour le trafic établi
iptables -A FORWARD -p tcp -s $WAN -d $LAN -m conntrack --ctstate NEW -j DROP
iptables -A FORWARD -p tcp -s $WAN -d $LAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser le LAN à sortir vers l'extérieur via NAT
# - La règle NAT (MASQUERADE) masque les adresses privées derrière l'IP publique du pare-feu
# - Les règles FORWARD complémentaires contrôlent la transmission des paquets:
#   * La première autorise le trafic sortant depuis le LAN
#   * La seconde n'autorise que le trafic entrant correspondant à des connexions déjà établies
#   Cette combinaison permet la navigation web tout en bloquant les tentatives de connexion entrantes
iptables -t nat -A POSTROUTING -s $LAN -o $WAN_IFACE -j MASQUERADE
iptables -A FORWARD -s $LAN -o $WAN_IFACE -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $WAN -i $WAN_IFACE -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Redirection du trafic HTTP vers le proxy Squid
# - Le trafic HTTP sortant du LAN est automatiquement redirigé vers le proxy Squid (port 3128) pour filtrer le contenu
iptables -t nat -A PREROUTING -i $LAN_IFACE -p tcp --dport 80 -j REDIRECT --to-port 3128

# Autorisation du loopback et connexions établies pour l'interface INPUT
# JUSTIFICATION:
# - L'interface de loopback (lo) doit être autorisée sans restriction pour permettre
#   le fonctionnement normal des services locaux et des communications inter-processus
# - La règle sur les connexions établies et associées permet au pare-feu de recevoir
#   les réponses à ses propres requêtes (DNS, mises à jour, etc.)
# - Sans ces règles, même le fonctionnement de base du système serait compromis
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Afficher les règles configurées
echo -e "\nRègles iptables configurées :"
iptables -L -v
echo -e "\nRègles NAT configurées :"
iptables -t nat -L -v
