#!/usr/bin/env bash
set -euo pipefail

# Config réseau dmz_wan
ip addr replace 19.4.3.17/29 dev eth0
ip route replace default via 19.4.3.18 dev eth0


echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf
a2enconf servername
service apache2 restart

cd /var/www/html/

echo "<html>
<head>
    <title>Mon serveur Apache dans Docker du WAN</title>
</head>
<body>
    <h1>Bienvenue sur le WAN</h1>
</body>
</html>" > /var/www/html/index.html

exec "$@"