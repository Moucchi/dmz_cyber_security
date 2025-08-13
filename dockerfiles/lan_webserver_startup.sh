#!/usr/bin/env bash
set -euo pipefail

# Config réseau lan_webserver
ip addr replace 19.4.3.2/29 dev eth0
ip route replace default via 19.4.3.3 dev eth0
echo "nameserver 19.4.3.3" > /etc/resolv.conf


echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf
a2enconf servername
service apache2 restart

cd /var/www/html/

echo "<html>
<head>
    <title>Serveur Apache dans Docker Interne</title>
</head>
<body>
    <h1>Bienvenue sur le serveur interne</h1>
</body>
</html>" > /var/www/html/index.html

exec "$@"