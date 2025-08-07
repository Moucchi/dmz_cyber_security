#!/bin/bash

# Configuration de Squid et SquidGuard pour le filtrage de contenu
# Ces commandes sont à exécuter sur la machine firewall

# =====================================================================
# JUSTIFICATION DU FILTRAGE DE CONTENU:
# L'architecture choisie (Squid + SquidGuard) offre:
# - Une solution robuste et éprouvée de filtrage web
# - Une grande flexibilité dans les politiques de filtrage (horaires, catégories, utilisateurs)
# - Un déploiement transparent qui ne nécessite pas de configuration sur les postes clients
# =====================================================================

# 1. Création d'un fichier de configuration personnalisé pour Squid
cat > /etc/squid/conf.d/00-custom.conf << 'EOF'
# Mode d'interception transparent du trafic HTTP
# JUSTIFICATION: Le mode "intercept" permet de capturer automatiquement le trafic HTTP
# redirigé par les règles iptables, sans configuration manuelle des navigateurs
http_port 3128 intercept

# Port local pour les requêtes générées par le proxy lui-même
# JUSTIFICATION: Ce port secondaire est nécessaire pour les requêtes que Squid génère
# lui-même, car il ne peut pas utiliser le port d'interception pour ses propres requêtes
http_port 127.0.0.1:3129

# Définition du réseau local
# JUSTIFICATION: Définit explicitement le réseau interne qui sera autorisé à utiliser le proxy
# Cette ACL limite l'utilisation du proxy aux seules machines du réseau LAN
acl localnet src 19.4.3.0/29

# Autoriser l'accès au réseau local
# JUSTIFICATION: Cette règle autorise uniquement les machines du réseau local
# à utiliser le proxy, renforçant la sécurité en empêchant les accès externes
http_access allow localnet

# Configuration de SquidGuard comme programme de réécriture d'URL
# JUSTIFICATION: Intègre SquidGuard comme filtre de contenu pour Squid
# SquidGuard analysera chaque URL demandée et pourra la bloquer selon les règles définies
url_rewrite_program /usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf

# Nombre d'instances du programme de réécriture
# JUSTIFICATION: Définit le nombre de processus SquidGuard à exécuter en parallèle
# 5 instances permettent de traiter efficacement plusieurs requêtes simultanées
url_rewrite_children 5
EOF

# 2. Configuration de SquidGuard pour le filtrage
cat > /etc/squidguard/squidGuard.conf << 'EOF'
# Répertoire de base des bases de données
# JUSTIFICATION: Spécifie l'emplacement des listes de blocage et des catégories de sites
dbhome /var/lib/squidguard/db

# Répertoire des logs
# JUSTIFICATION: Centralise les journaux avec ceux de Squid pour faciliter l'analyse
logdir /var/log/squid

# Définition de la source (réseau LAN)
# JUSTIFICATION: Identifie le réseau LAN comme source de trafic à filtrer
# Cette définition permet d'appliquer des politiques spécifiques à ce réseau
src lan {
    ip 19.4.3.0/29
}

# Définition des plages horaires de travail
# JUSTIFICATION: Établit les heures de bureau pendant lesquelles des règles
# de filtrage plus strictes seront appliquées
# Cette configuration permet d'adapter dynamiquement le filtrage selon les horaires
time workhours {
    weekly mtwhf 08:00-12:00  # Matinées du lundi au vendredi
    weekly mtwhf 14:00-18:00  # Après-midis du lundi au vendredi
}

# Catégories de sites à filtrer
# JUSTIFICATION: Organisation des sites web en catégories pour un filtrage ciblé
dest porn {
    # JUSTIFICATION: Blocage des sites à caractère pornographique
    # Ce filtrage est nécessaire pour des raisons légales et de conformité
    domainlist porn/domains
    urllist porn/urls
}

dest social {
    # JUSTIFICATION: Catégorie des réseaux sociaux
    # Ces sites sont filtrés pendant les heures de travail pour améliorer la productivité
    domainlist social/domains
    urllist social/urls
}

# Règles d'accès
# JUSTIFICATION: Définition de politiques de filtrage différenciées selon le contexte
acl {
    # Pendant les heures de travail
    # JUSTIFICATION: Politique stricte pendant les heures de bureau
    # Bloque à la fois les sites pornographiques et les réseaux sociaux
    lan within workhours {
        pass !porn !social all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    # En dehors des heures de travail
    # JUSTIFICATION: Politique plus souple hors heures de bureau
    # Seuls les sites pornographiques restent bloqués, les réseaux sociaux sont autorisés
    lan {
        pass !porn all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    # Règle par défaut
    # JUSTIFICATION: Politique restrictive par défaut (principe de moindre privilège)
    # Bloque tout accès non explicitement autorisé par les règles précédentes
    default {
        pass none
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }
}
EOF

# 3. Création des listes de sites pornographiques à bloquer
mkdir -p /var/lib/squidguard/db/porn
cat > /var/lib/squidguard/db/porn/domains << 'EOF'
pornhub.com
xvideos.com
xnxx.com
redtube.com
youporn.com
EOF
touch /var/lib/squidguard/db/porn/urls

# 4. Création des listes de réseaux sociaux à bloquer
mkdir -p /var/lib/squidguard/db/social
cat > /var/lib/squidguard/db/social/domains << 'EOF'
facebook.com
twitter.com
instagram.com
tiktok.com
linkedin.com
snapchat.com
pinterest.com
EOF
touch /var/lib/squidguard/db/social/urls

# 5. Compilation des bases de données et ajustement des permissions
squidGuard -b -d -C all
chown -R proxy:proxy /var/lib/squidguard/db
chown -R proxy:proxy /var/log/squid
chmod -R 755 /var/lib/squidguard/db

# 6. Vérification de la configuration
squid -k parse

# 7. Redémarrage du service Squid
service squid restart
