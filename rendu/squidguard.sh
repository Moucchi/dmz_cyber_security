#!/bin/bash

# Configuration de Squid et SquidGuard pour le filtrage de contenu
# Ces commandes sont à exécuter sur la machine firewall

# 1. Création d'un fichier de configuration personnalisé pour Squid
cat > /etc/squid/conf.d/00-custom.conf << 'EOF'
# Mode d'interception transparent du trafic HTTP
http_port 3128 intercept

# Port local pour les requêtes générées par le proxy lui-même
http_port 127.0.0.1:3129

# Définition du réseau local
acl localnet src 19.4.3.0/29

# Autoriser l'accès au réseau local
http_access allow localnet

# Configuration de SquidGuard comme programme de réécriture d'URL
url_rewrite_program /usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf

# Nombre d'instances du programme de réécriture
url_rewrite_children 5
EOF

# 2. Configuration de SquidGuard pour le filtrage
cat > /etc/squidguard/squidGuard.conf << 'EOF'
# Répertoire de base des bases de données
dbhome /var/lib/squidguard/db

# Répertoire des logs
logdir /var/log/squid

# Définition de la source (réseau LAN)
src lan {
    ip 19.4.3.0/29
}

# Définition des plages horaires de travail
time workhours {
    weekly mtwhf 08:00-12:00
    weekly mtwhf 14:00-18:00
}

# Catégories de sites à filtrer
dest porn {
    domainlist porn/domains
    urllist porn/urls
}

dest social {
    domainlist social/domains
    urllist social/urls
}

# Règles d'accès
acl {
    # Pendant les heures de travail
    lan within workhours {
        pass !porn !social all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    # En dehors des heures de travail
    lan {
        pass !porn all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    # Règle par défaut
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
