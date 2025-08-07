#!/bin/bash

# Configuration de Snort pour la détection d'intrusion
# Ces commandes sont à exécuter sur la machine public-server (DMZ)

# =====================================================================
# JUSTIFICATION DE L'IMPLÉMENTATION IDS:
# Snort est installé sur le serveur public de la DMZ car:
# - Ce serveur est directement exposé aux menaces externes
# - Cette position permet de détecter les attaques ciblant les services publics
# - L'IDS peut identifier les tentatives d'exploitation même si le pare-feu les autorise
# =====================================================================

# 1. Sauvegarde de la configuration d'origine
# JUSTIFICATION: Permet de revenir à la configuration initiale en cas de problème
cp /etc/snort/snort.conf /etc/snort/snort.conf.bak

# 2. Modification des variables réseau dans snort.conf
# JUSTIFICATION: Configuration des variables réseau pour définir précisément ce qui doit être protégé
# - HOME_NET est défini comme l'adresse IP du serveur DMZ (19.4.3.9)
#   Cette précision permet de concentrer l'analyse sur le trafic destiné à ce serveur spécifique
# - EXTERNAL_NET est défini comme tout ce qui n'est pas HOME_NET (!$HOME_NET)
#   Cette approche considère tout trafic externe comme potentiellement dangereux
sed -i 's/^ipvar HOME_NET.*/ipvar HOME_NET 19.4.3.9/' /etc/snort/snort.conf
sed -i 's/^ipvar EXTERNAL_NET.*/ipvar EXTERNAL_NET !$HOME_NET/' /etc/snort/snort.conf

# 3. Création des règles de détection personnalisées
# JUSTIFICATION: Définition de règles spécifiques adaptées à notre environnement
cat > /etc/snort/rules/local.rules << 'EOF'
# ==== SCANS DE PORT ====
# JUSTIFICATION: Détection des activités de reconnaissance, souvent précurseurs d'attaques
# Cette règle identifie les scans SYN (furtifs) par la détection de 5+ paquets SYN
# en moins d'une minute depuis une même source
alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP SYN scan détecté"; flags:S,12; threshold:type threshold, track by_src, count 5, seconds 60; classtype:attempted-recon; sid:2000001; rev:1;)

# JUSTIFICATION: Détection des scans de type "connect" (moins furtifs mais plus courants)
# Le seuil est fixé à 10 tentatives en 60 secondes pour réduire les faux positifs
alert tcp any any -> $HOME_NET any (msg:"[SCAN] TCP Connect scan détecté"; flags:S; threshold:type threshold, track by_src, count 10, seconds 60; classtype:attempted-recon; sid:2000002; rev:1;)

# JUSTIFICATION: Détection des scans UDP, souvent utilisés pour identifier les services non-TCP
# Le seuil est plus élevé (15 paquets) car les scans UDP génèrent plus de bruit
alert udp any any -> $HOME_NET any (msg:"[SCAN] UDP scan détecté"; threshold:type threshold, track by_src, count 15, seconds 60; classtype:attempted-recon; sid:2000003; rev:1;)

# ==== ATTAQUES DoS ====
# JUSTIFICATION: Protection contre les attaques par déni de service
# Cette règle détecte les attaques par inondation ICMP ("ping flood")
# Le seuil de 30 paquets ICMP en 10 secondes indique une activité anormale
alert icmp any any -> $HOME_NET any (msg:"[DoS] Attaque ICMP flood détectée"; threshold:type threshold, track by_src, count 30, seconds 10; classtype:attempted-dos; sid:2000010; rev:1;)

# JUSTIFICATION: Détection des attaques SYN flood qui visent à épuiser les ressources du serveur
# La règle utilise flow:stateless car les attaques SYN flood ne suivent pas l'état normal des connexions
# Le seuil plus élevé (50 paquets) est adapté à la nature de cette attaque qui implique un grand volume
alert tcp any any -> $HOME_NET any (msg:"[DoS] Attaque SYN flood détectée"; flags:S,12; flow:stateless; threshold:type threshold, track by_src, count 50, seconds 10; classtype:attempted-dos; sid:2000011; rev:1;)

# ==== ATTAQUES WEB ====
# JUSTIFICATION: Protection spécifique des applications web hébergées dans la DMZ
# Cette règle détecte les tentatives d'injection SQL basiques via la recherche de mots-clés typiques
# L'option nocase permet de détecter les variations de casse utilisées pour contourner la détection
alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible injection SQL détectée"; content:"UNION SELECT"; nocase; classtype:web-application-attack; sid:2000020; rev:1;)

# JUSTIFICATION: Détection des attaques XSS (Cross-Site Scripting)
# Ces attaques permettent l'injection de code JavaScript malveillant dans les pages web
# La détection se concentre sur la balise <script> qui est un indicateur courant d'attaque XSS
alert tcp any any -> $HOME_NET 80 (msg:"[WEB] Possible attaque XSS détectée"; content:"<script>"; nocase; classtype:web-application-attack; sid:2000022; rev:1;)
EOF

# 4. Ajout des règles de journalisation à snort.conf
# JUSTIFICATION: Configuration de plusieurs formats de journalisation pour différents usages
# Ces lignes sont généralement commentées dans la configuration par défaut
cat >> /etc/snort/snort.conf << 'EOF'

# Configuration de la journalisation
# JUSTIFICATION: Mise en place de formats de journalisation complémentaires
# - log_tcpdump: Capture complète des paquets pour analyse forensique détaillée
# - alert_fast: Format texte simple et rapide pour consultation humaine
# - alert_csv: Format structuré pour importation dans des outils d'analyse ou SIEM
output log_tcpdump: /var/log/snort/tcpdump.log
output alert_fast: /var/log/snort/alert.fast
output alert_csv: /var/log/snort/alert.csv default
EOF

# 5. Création du répertoire pour les logs
# JUSTIFICATION: Préparation de l'environnement de journalisation
# Le répertoire doit exister et avoir les bonnes permissions pour que Snort puisse y écrire
mkdir -p /var/log/snort/
# Attribution des droits au utilisateur et groupe snort pour une exécution sécurisée
# Cela suit le principe du moindre privilège en évitant d'exécuter Snort en tant que root
chown -R snort:snort /var/log/snort/

# 6. Vérification de la configuration
# JUSTIFICATION: Test de la configuration avant déploiement
# L'option -T effectue une vérification syntaxique sans démarrer réellement Snort
# Cela permet de détecter les erreurs de configuration avant la mise en production
snort -T -c /etc/snort/snort.conf -i eth0

# 7. Démarrage de Snort
# JUSTIFICATION: Instructions pour le déploiement en production ou en test
# Deux modes de démarrage sont proposés selon le contexte d'utilisation:
# Options de la commande:
# -D : mode démon (arrière-plan)
# -q : mode silencieux (moins de messages)
# -u/-g : exécution sous l'utilisateur/groupe snort (principe du moindre privilège)
# -c : chemin vers le fichier de configuration
# -i : interface réseau à surveiller
# -l : répertoire pour les logs
echo "snort -D -q -u snort -g snort -c /etc/snort/snort.conf -i eth0 -l /var/log/snort/"
echo "Pour démarrer Snort en mode interactif (pour les tests), exécutez :"
# L'option -A console affiche les alertes directement dans le terminal
# Ce mode est utile pour le débogage et les tests en temps réel
echo "snort -A console -q -u snort -g snort -c /etc/snort/snort.conf -l /var/log/snort/ -i eth0"

echo "Snort est configuré pour détecter les scans, les attaques DoS et les attaques web."
# Les alertes seront enregistrées dans /var/log/snort/."
