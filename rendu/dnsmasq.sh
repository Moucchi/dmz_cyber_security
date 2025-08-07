#!/bin/bash

# Configuration de DNSmasq sur le pare-feu
# Ces commandes sont à exécuter sur la machine firewall

# Création du fichier de configuration principal
cat > /etc/dnsmasq.conf << 'EOF'
# Interface sur laquelle écouter (interface LAN)
interface=eth1

# Ne pas lire /etc/resolv.conf
no-resolv

# Utiliser Google DNS comme serveur DNS externe
server=8.8.8.8

# Étendre les noms d'hôte avec le domaine
expand-hosts

# Définir le domaine local
domain=lan.local
EOF

# Ajout d'entrées DNS locales pour les tests
# Ces entrées seront servies par dnsmasq aux clients du LAN
echo "19.4.3.17 pornhub.com" >> /etc/hosts
echo "19.4.3.17 facebook.com" >> /etc/hosts
echo "19.4.3.17 twitter.com" >> /etc/hosts
echo "19.4.3.9 webserver.dmz" >> /etc/hosts
echo "19.4.3.2 internal.lan" >> /etc/hosts

# Démarrage du service DNSmasq
service dnsmasq restart

# Vérification de l'état du service
service dnsmasq status