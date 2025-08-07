#!/bin/bash

# Configuration de Snort pour la détection d'intrusion
# Ces commandes sont à exécuter sur la machine public-server (DMZ)

# 1. Sauvegarde de la configuration d'origine
cp /etc/snort/snort.conf /etc/snort/snort.conf.bak

# 2. Modification des variables réseau dans snort.conf
# Ces lignes remplacent les définitions existantes des variables HOME_NET et EXTERNAL_NET
sed -i 's/^ipvar HOME_NET.*/ipvar HOME_NET 19.4.3.9/' /etc/snort/snort.conf
sed -i 's/^ipvar EXTERNAL_NET.*/ipvar EXTERNAL_NET !$HOME_NET/' /etc/snort/snort.conf

# 3. Création des règles de détection personnalisées
cat > /etc/snort/rules/local.rules << 'EOF'
# ==== SCANS DE PORT ====
alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP SYN scan détecté"; flags:S,12; threshold:type threshold, track by_src, count 5, seconds 60; classtype:attempted-recon; sid:2000001; rev:1;)

alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP Connect scan détecté"; flags:S; threshold:type threshold, track by_src, count 10, seconds 60; classtype:attempted-recon; sid:2000002; rev:1;)

alert udp any any -> $HOME_NET any (msg:"[SCAN] UDP scan détecté"; threshold:type threshold, track by_src, count 15, seconds 60; classtype:attempted-recon; sid:2000003; rev:1;)

# ==== ATTAQUES DoS ====
alert icmp any any -> $HOME_NET any (msg:"[DoS] Attaque ICMP flood détectée"; threshold:type threshold, track by_src, count 30, seconds 10; classtype:attempted-dos; sid:2000010; rev:1;)

alert tcp any any -> $HOME_NET any (msg:"[DoS] Attaque SYN flood détectée"; flags:S,12; flow:stateless; threshold:type threshold, track by_src, count 50, seconds 10; classtype:attempted-dos; sid:2000011; rev:1;)

# ==== ATTAQUES WEB ====
alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible injection SQL détectée"; content:"UNION SELECT"; nocase; classtype:web-application-attack; sid:2000020; rev:1;)

alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible attaque XSS détectée"; content:"<script>"; nocase; classtype:web-application-attack; sid:2000022; rev:1;)
EOF

# 4. Ajout des règles de journalisation à snort.conf
# Ces lignes sont généralement commentées dans la configuration par défaut
# Assurez-vous qu'elles sont décommentées ou ajoutez-les si nécessaire
cat >> /etc/snort/snort.conf << 'EOF'

# Configuration de la journalisation
output log_tcpdump: /var/log/snort/tcpdump.log
output alert_fast: /var/log/snort/alert.fast
output alert_csv: /var/log/snort/alert.csv default
EOF

# 5. Création du répertoire pour les logs
mkdir -p /var/log/snort/
chown -R snort:snort /var/log/snort/

# 6. Vérification de la configuration
snort -T -c /etc/snort/snort.conf -i eth0

# 7. Démarrage de Snort
echo "Pour démarrer Snort en mode démon, exécutez la commande suivante :"
echo "snort -D -q -u snort -g snort -c /etc/snort/snort.conf -i eth0 -l /var/log/snort/"
echo "Pour démarrer Snort en mode interactif (pour les tests), exécutez :"
echo "snort -A console -q -u snort -g snort -c /etc/snort/snort.conf -l /var/log/snort/ -i eth0"

echo "Les alertes seront enregistrées dans /var/log/snort/."
