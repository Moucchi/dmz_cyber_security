#!/bin/bash

# Configuration de DNSmasq sur le pare-feu
# Ces commandes sont à exécuter sur la machine firewall

# =====================================================================
# JUSTIFICATION DE L'IMPLÉMENTATION DNS:
# - DNSmasq est utilisé comme serveur DNS local pour plusieurs raisons:
#   2. Sécurité: contrôle des résolutions DNS et possibilité de blocage de domaines
#   4. Flexibilité: permet de définir des entrées DNS locales personnalisées
# =====================================================================

# Création du fichier de configuration principal
cat > /etc/dnsmasq.conf << 'EOF'
# Interface sur laquelle écouter (interface LAN)
# JUSTIFICATION: Limite le service DNS à l'interface LAN uniquement
# Ceci empêche l'exposition du service DNS vers l'extérieur ou la DMZ, réduisant la surface d'attaque
interface=eth1

# Ne pas lire /etc/resolv.conf
# JUSTIFICATION: Empêche DNSmasq d'utiliser les serveurs DNS configurés sur le pare-feu
# Cette option est nécessaire pour garantir l'utilisation exclusive des serveurs DNS spécifiés
no-resolv

# Utiliser Google DNS comme serveur DNS externe
# JUSTIFICATION: Serveur DNS public fiable pour résoudre les requêtes externes
# Dans un environnement de production, on utiliserait idéalement les serveurs DNS de l'entreprise
server=8.8.8.8

# Étendre les noms d'hôte avec le domaine
# JUSTIFICATION: Permet d'utiliser des noms courts pour les machines du réseau local
# Par exemple, "serveur" sera automatiquement étendu à "serveur.lan.local"
expand-hosts

# Définir le domaine local
# JUSTIFICATION: Crée un espace de noms privé pour le réseau interne
# Facilite l'identification des ressources internes et la configuration DNS
domain=lan.local
EOF

# Ajout d'entrées DNS locales pour les tests
# Ces entrées seront servies par dnsmasq aux clients du LAN
# - Les trois premières entrées implémentent une politique de filtrage DNS:
#   * Les sites pornographiques sont bloqués pour des raisons de conformité et de productivité
#   * Les réseaux sociaux sont redirigés pour limiter leur utilisation en milieu professionnel
# - Les deux dernières entrées facilitent l'accès aux serveurs internes par nom plutôt que par IP:
#   * webserver.dmz pointe vers le serveur public dans la DMZ
#   * internal.lan pointe vers le serveur interne du LAN
echo "19.4.3.17 pornhub.com" >> /etc/hosts
echo "19.4.3.17 facebook.com" >> /etc/hosts
echo "19.4.3.17 twitter.com" >> /etc/hosts
echo "19.4.3.9 webserver.dmz" >> /etc/hosts
echo "19.4.3.2 internal.lan" >> /etc/hosts

# Démarrage du service DNSmasq
service dnsmasq restart