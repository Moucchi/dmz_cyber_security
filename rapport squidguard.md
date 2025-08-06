# Rapport : Mise en place d’une architecture DMZ via GNS3 et Docker

## Membres du groupe :
  - 1979
  - 2075

## Introduction

L’objectif de ce travail pratique est de mettre en œuvre une architecture réseau sécurisée intégrant une zone
démilitarisée (DMZ), en utilisant les outils GNS3 et Docker. Ce projet s’inscrit dans le cadre de l’apprentissage des
techniques de défense périmétrique d’un système d’information. Il permet de concevoir, configurer et
analyser une topologie réseau complète, comprenant la mise en place d’une DMZ, la gestion des règles de filtrage et de
NAT, le déploiement de solutions de détection/prévention d’intrusion ainsi que l’analyse des logs pour valider la
politique de sécurité. À travers la réalisation de ce TP, les compétences en conception d’architectures sécurisées, en
administration réseau et en cybersécurité seront renforcées.

## Méthodologie

La méthodologie suivie pour la réalisation de ce travail pratique s’articule autour des étapes suivantes

### 1. **Création des images Docker**

La première étape a consisté à créer les images Docker nécessaires pour simuler l'ensemble des machines de notre architecture DMZ. Plusieurs Dockerfiles ont été développés, chacun correspondant à un rôle spécifique dans l'infrastructure :

#### 1.1 Client LAN (`ubuntu_client`)

Cette image simule une machine cliente dans le réseau LAN interne de l'entreprise :

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lynx \
    iputils-ping \
    traceroute \
    curl \
    wget \
    nano \
    openssh-client \
    iproute2 \
    dnsutils
```

**Rôle** : Machine cliente utilisée pour tester l'accès depuis le LAN vers la DMZ et Internet, et valider les règles de filtrage du pare-feu.

#### 1.2 Pare-feu (`ubuntu_firewall`)

Cette image centralise toutes les fonctions de sécurité réseau :

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    iptables \
    iproute2 \
    tcpdump \
    squid \
    squidguard \
    squid-cgi \
    apache2-utils \
    dnsutils \
    iputils-ping \
    curl \
    wget \
    nano \
    iftop \
    tcptrack \
    wondershaper \
    cron
```

**Rôle** : Pare-feu principal avec filtrage de paquets (iptables), proxy web (Squid), filtrage de contenu (SquidGuard) et outils de monitoring réseau.

#### 1.3 Serveur Web DMZ (`ubuntu_webserver`)

Cette image héberge le serveur web situé dans la DMZ et intègre des outils de supervision et de sécurité :

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apache2 \
    lynx \
    iputils-ping \
    traceroute \
    curl \
    wget \
    nano \
    openssh-client \
    openssh-server \
    iproute2 \
    dnsutils \
    apache2-utils \
    tcpdump \
    net-tools \
    snort 
```

**Rôle** : Serveur web Apache situé dans la DMZ, accessible depuis Internet mais isolé du réseau LAN interne. Il intègre également des outils de supervision (`tcpdump`, `net-tools`) et un IDS (`snort`) pour la détection d'intrusions.

#### 1.4 Serveur Web LAN (`ubuntu_lan_webserver`)

Cette image simule un serveur web interne au LAN :

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apache2 \
    lynx \
    iputils-ping \
    traceroute \
    curl \
    wget \
    nano \
    openssh-client \
    iproute2 \
    dnsutils \
    apache2-utils
```

**Rôle** : Serveur web interne au LAN, utilisé pour tester l'accès et l'isolation entre le LAN et la DMZ/WAN.

#### 1.5 WAN (`ubuntu_wan`)

Cette image simule une machine externe sur Internet :

```dockerfile
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    hping3 \
    lynx \
    iputils-ping \
    traceroute \
    curl \
    wget \
    nano \
    openssh-client \
    iproute2 \
    apache2 \
    dnsutils \
    tcpdump
```

**Rôle** : Machine externe utilisée pour simuler des connexions depuis Internet et tester les règles de sécurité.

Toutes ces images utilisent Ubuntu 20.04 comme base et incluent la variable d'environnement `DEBIAN_FRONTEND=noninteractive` pour automatiser l'installation des paquets sans interaction utilisateur.

### 2.  **Mise en place de la topologie**

#### 2.1 **Création des containers dockers dans gns3**
##### firewall
- docker image : ubuntu_firewall
- interfaces : 3
- console : telnet

##### public-server
  - docker image : ubuntu_webserver
  - interfaces : 1
  - console : telnet

##### internal-server
  - docker image : ubuntu_lan_webserver
  - interfaces : 1
  - console : telnet

##### internal-desktop
  - docker image : ubuntu_client
  - interfaces : 1
  - console : telnet

##### internet
  - docker image : ubuntu_wan
  - interfaces : 1
  - console : telnet

#### 2.2 **Mise en place de la topologie dans gns3**

##### 1. Instanciation et liaison des containers

On commence par instancier les containers et les relier comme dans la figure ci-dessous :

![Topologie sans adresses](mise_en_place_topologie.png)

**Structure réseau :**

- **dmz-switch**
  - e0 ←→ eth2 firewall
  - e1 ←→ eth0 public-server

- **firewall**
  - eth0 ←→ e0 internal-switch
  - eth1 ←→ e0 internal-switch
  - eth2 ←→ e1 dmz-switch

- **internal-desktop**
  - eth0 ←→ e1 internal-switch

- **internal-server**
  - eth0 ←→ e2 internal-switch

- **internal-switch**
  - e0 ←→ eth1 firewall
  - e1 ←→ eth0 internal-desktop
  - e2 ←→ eth0 internal-server

- **internet**
  - eth0 ←→ eth0 firewall

- **public-server**
  - eth0 ←→ e1 dmz-switch

###### Image de la liaison des noeuds :
![Liaison des noeuds](image.png)

##### 2. Démarrage et configuration des adresses IP

Après le démarrage de toutes les instances, on configure leurs adresses IP comme suit :

###### a) LAN
- **internal-desktop**
  ```bash
  ip a add 19.4.3.1/29 dev eth0
  ip route add default via 19.4.3.3 dev eth0
  ```
- **internal-server**
  ```bash
  ip a add 19.4.3.2/29 dev eth0
  ip route add default via 19.4.3.3 dev eth0
  ```

###### b) WAN
- **internet**
  ```bash
  ip a add 19.4.3.17/29 dev eth0
  ip route add default via 19.4.3.18 dev eth0
  ```

###### c) DMZ
- **public-server (DMZ)**
  ```bash
  ip a add 19.4.3.9/29 dev eth0
  ip route add default via 19.4.3.11 dev eth0
  ```

###### d) Pare-feu
- **firewall**
  ```bash
  ip a add 19.4.3.3/29 dev eth1
  ip a add 19.4.3.11/29 dev eth2
  ip a add 19.4.3.18/29 dev eth0
  sysctl -w net.ipv4.ip_forward=1
  ```

###### Subnets utilisés
```bash
WAN="19.4.3.16/29"
LAN="19.4.3.0/29"
DMZ="19.4.3.8/29"
```

###### Image de la topologie :
![Image topologie](image_topologie.png)



#### 2.3. Test de la topologie de base
###### 1. LAN <-> LAN
- **internal-desktop -> internal-server**
 ```bash
  ping 19.4.3.2
  ```

- **internal-server -> internal-desktop**
```bash
  ping 19.4.3.1
  ```

###### 2. firewall <-> LAN
- **firewall -> internal-desktop**
 ```bash
  ping 19.4.3.1
  ```

- **firewall -> internal-server**
 ```bash
  ping 19.4.3.2
  ```

- **internal-server -> firewall**
 ```bash
  ping 19.4.3.3
  ```

- **internal-desktop -> firewall**
 ```bash
  ping 19.4.3.3
  ```

###### 3. firewall <-> WAN
- **firewall -> internet**
 ```bash
  ping 19.4.3.17
  ```

- **internet -> firewall**
 ```bash
  ping 19.4.3.18
  ```

###### 4. firewall <-> DMZ
- **firewall -> DMZ**
 ```bash
  ping 19.4.3.9
  ```

- **DMZ -> firewall**
 ```bash
  ping 19.4.3.11
  ```

###### 5. DMZ <-> LAN
- **LAN -> DMZ**
 ```bash
  ping 19.4.3.9
  ```

- **DMZ -> LAN**
 ```bash
  ping 19.4.3.1
  ping 19.4.3.2
  ```

###### 6. WAN <-> DMZ
- **WAN -> DMZ**
 ```bash
  ping 19.4.3.9
  ```
- **DMZ -> WAN**
 ```bash
  ping 19.4.3.17
  ```

#### 3. Configuration des servers
###### 3.1 public-server
 ```bash
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

  ```

###### 3.2 internal-server
 ```bash
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

  ```
###### 3.3 internet

```bash
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

```

### 3.  **Configuration des services et comportements attendus**
#### 3.1. **Pare-feu**
On definit tout d'abors les varables à utiliser :
 ```bash
  WAN="19.4.3.16/29"
  LAN="19.4.3.0/29"
  DMZ="19.4.3.8/29"
  HTTP="80"
  HTTPS="443"
  SSH="22"

  WAN_IFACE="eth0"
  DMZ_IFACE="eth1"
  LAN_IFACE="eth2"
  ```

Etant donné qu'on a crée l'image docker à partir d'une image **ubuntu vierge** et qu'on a **nous meme installé les packets necessaires**, **``iptables`` ne contient encore aucune regle**.

##### - Autoriser HTTP, HTTPS, SSH vers la DMZ (depuis WAN et LAN)
 ```bash
  iptables -A FORWARD -p tcp -s $LAN,$WAN -d $DMZ -m multiport --dports $HTTP,$HTTPS,$SSH -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -s $DMZ -d $LAN,$WAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ```

![Autoriser HTTP, HTTPS, SSH vers la DMZ ](image-1.png)

##### -  Bloquer tout autre port ou protocole par défaut
 ```bash
  iptables -P FORWARD DROP
  ```

![Bloquer tout autre port ou protocole par défaut](image-3.png)

##### -  Bloquer l’accès du WAN vers le LAN
Déja inclut avec :
 ```bash
  iptables -P FORWARD DROP
  ```

##### - Autoriser le LAN à sortir vers l’extérieur via NAT
 ```bash
  iptables -t nat -A POSTROUTING -s $LAN -o $WAN_IFACE -j MASQUERADE
  iptables -A FORWARD -s $LAN -o $WAN_IFACE -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -s $WAN -i $WAN_IFACE -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ```
![Autoriser le LAN à sortir vers l’extérieur via NAT](image-2.png)
- ping depuis LAN vers WAN : 
  - ![alt text](image-6.png)
- affichage des packets dans internet :
  - ![alt text](image-7.png)

##### - Bloquer les sites pornographiques (SquidGuard)
Il faut d'abord configurer iptables pour rediriger le trafic vers Squid :
```bash
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-port 3128

iptables -A INPUT -p tcp --dport 3128 -j ACCEPT
iptables -A INPUT -p tcp --dport 3129 -j ACCEPT
``` 

Configurer ensuite squid : 
```bash
cat > /etc/squid/squid.conf << 'EOF'
http_port 3128 intercept
http_port 3129

acl localnet src 19.4.3.0/29
acl localnet src 19.4.3.8/29
acl localnet src 19.4.3.16/29

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access deny all

redirect_program /usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf
redirect_children 5

access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

cache_dir ufs /var/spool/squid 100 16 256

httpd_suppress_version_string on
EOF
```
Configuration du fichier de configuration de squidguard :

```bash
cat > /etc/squidguard/squidGuard.conf << 'EOF'
#
# CONFIG FILE FOR SQUIDGUARD
#
# Caution: do NOT use comments inside { }
#

dbhome /var/lib/squidguard/db
logdir /var/log/squidguard

#
# TIME RULES:
# abbrev for weekdays: 
# s = sun, m = mon, t =tue, w = wed, h = thu, f = fri, a = sat

time workhours {
weekly mtwhf 08:00 - 16:30
date *-*-01  08:00 - 16:30
}

#
# SOURCE ADDRESSES:
#

src admin {
  ip 19.4.3.2
}

src internal-desktop {
  ip 19.4.3.1
}

src lan {
  ip 19.4.3.0/29
}

#
# DESTINATION CLASSES:
#
# [see also in file dest-snippet.txt]

dest blockedsite {
    domainlist blockeddomains
}

#dest adult {
#domainlistBL/adult/domains
#urllistBL/adult/urls
#expressionlistBL/adult/expressions
#redirect http://admin.foo.bar.de/cgi-bin/blocked.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
#}

#
# ACL RULES:
#


acl {
    admin {
        pass all
    }
    lan {
        pass !blockedsite all
        redirect http://localhost/blocked.html
    }
    default {
        pass none
        redirect http://localhost/blocked.html
    }
}

EOF
```

```bash
mkdir -p /var/lib/squidguard/db

cat > /var/lib/squidguard/db/blockeddomains << 'EOF'
x.adulte.com
EOF
```

```bash
mkdir -p /var/log/squidguard
mkdir -p /var/spool/squid

# Compilation de la base de données SquidGuard AVANT le démarrage de Squid
squidGuard -C all

# Configuration des permissions
chown -R proxy:proxy /var/lib/squidguard/db
chown -R proxy:proxy /var/log/squidguard
chown -R proxy:proxy /var/spool/squid
chmod -R 644 /var/lib/squidguard/db/blockeddomains

# Initialisation du cache Squid
squid -z
```

```bash
cat > /var/www/html/blocked.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Accès bloqué</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Accès refusé</h1>
    <p>Ce site est bloqué par la politique de sécurité.</p>
    <p>Contact: admin@moucchi.mg</p>
</body>
</html>
EOF
```

```bash
echo "ServerName localhost" >> /etc/apache2/apache2.conf
echo "127.0.0.1 firewall" >> /etc/hosts
service apache2 start

squid -k parse

killall squid 2>/dev/null || true
service squid start


echo "interface=eth2" >> /etc/dnsmasq.conf  
echo "interface=eth1" >> /etc/dnsmasq.conf  

echo "19.4.3.17 x.adulte.com" >> /etc/hosts

service dnsmasq restart


iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
```

LAN : 
```bash
echo "nameserver 19.4.3.3" > /etc/resolv.conf
```