#!/usr/bin/env bash
set -euo pipefail

# Config réseau dmz_webserver
ip addr replace 19.4.3.9/29 dev eth0
ip route replace default via 19.4.3.11 dev eth0

echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf
a2enconf servername
service apache2 restart

cd /var/www/html/

echo "<html>
<head>
    <title>Serveur Apache dans Docker DMZ</title>
</head>
<body>
    <h1>Bienvenue sur le serveur publique</h1>
</body>
</html>" > /var/www/html/index.html

a2enmod ssl
a2enmod rewrite

mkdir -p /etc/ssl/private
mkdir -p /etc/ssl/certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj "/C=FR/ST=State/L=City/O=Organization/OU=OrgUnit/CN=webserver"

cat > /etc/apache2/sites-available/default-ssl.conf << 'EOF'
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        DocumentRoot /var/www/html
        
        SSLEngine on
        SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt
        SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key
        
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
    </VirtualHost>
</IfModule>
EOF

a2ensite default-ssl

service apache2 restart

mkdir -p /var/run/sshd
ssh-keygen -A
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
useradd -m -s /bin/bash user
echo "user:root" | chpasswd
service ssh start

cp /etc/snort/snort.conf /etc/snort/snort.conf.bak
sed -i 's/^ipvar HOME_NET.*/ipvar HOME_NET 19.4.3.9/' /etc/snort/snort.conf
sed -i 's/^ipvar EXTERNAL_NET.*/ipvar EXTERNAL_NET !$HOME_NET/' /etc/snort/snort.conf

cat > /etc/snort/rules/local.rules << 'EOF'
alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP SYN scan détecté"; flags:S,12; threshold:type threshold, track by_src, count 5, seconds 60; classtype:attempted-recon; sid:2000001; rev:1;)

alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP Connect scan détecté"; flags:S; threshold:type threshold, track by_src, count 10, seconds 60; classtype:attempted-recon; sid:2000002; rev:1;)

alert udp any any -> $HOME_NET any (msg:"[SCAN] UDP scan détecté"; threshold:type threshold, track by_src, count 15, seconds 60; classtype:attempted-recon; sid:2000003; rev:1;)

alert icmp any any -> $HOME_NET any (msg:"[DoS] Attaque ICMP flood détectée"; threshold:type threshold, track by_src, count 30, seconds 10; classtype:attempted-dos; sid:2000010; rev:1;)

alert tcp any any -> $HOME_NET any (msg:"[DoS] Attaque SYN flood détectée"; flags:S,12; flow:stateless; threshold:type threshold, track by_src, count 50, seconds 10; classtype:attempted-dos; sid:2000011; rev:1;)

alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible injection SQL détectée"; content:"UNION SELECT"; nocase; classtype:web-application-attack; sid:2000020; rev:1;)

alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible attaque XSS détectée"; content:"<script>"; nocase; classtype:web-application-attack; sid:2000022; rev:1;)
EOF

mkdir -p /var/log/snort/
chown -R snort:snort /var/log/snort/
snort -T -c /etc/snort/snort.conf -i eth0

echo "Mampiditra ny type ana output sisa : nano /etc/snort/snort.conf."

exec "$@"