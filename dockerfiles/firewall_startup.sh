#!/usr/bin/env bash
set -euo pipefail

ip a add 19.4.3.3/29 dev  eth1
ip a add 19.4.3.11/29 dev  eth2
ip a add 19.4.3.18/29 dev  eth0

sysctl -w net.ipv4.ip_forward=1

WAN="19.4.3.16/29"
LAN="19.4.3.0/29"
DMZ="19.4.3.8/29"
HTTP="80"
HTTPS="443"
SSH="22"

WAN_IFACE="eth0"
LAN_IFACE="eth1"
DMZ_IFACE="eth2"

iptables -P FORWARD DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -p tcp -s $LAN,$WAN -d $DMZ -m multiport --dports $HTTP,$HTTPS,$SSH -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $DMZ -d $LAN,$WAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -p tcp -s $WAN -d $LAN -m conntrack --ctstate NEW -j DROP
iptables -A FORWARD -p tcp -s $WAN -d $LAN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -t nat -A POSTROUTING -s $LAN -o $WAN_IFACE -j MASQUERADE
iptables -A FORWARD -s $LAN -o $WAN_IFACE -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $WAN -i $WAN_IFACE -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -t nat -A PREROUTING -i $LAN_IFACE -p tcp --dport 80 -j REDIRECT --to-port 3128

cat > /etc/dnsmasq.conf << 'EOF'
interface=eth1
no-resolv
server=8.8.8.8
expand-hosts
domain=lan.local
EOF

echo "19.4.3.17 pornhub.com" >> /etc/hosts
echo "19.4.3.17 facebook.com" >> /etc/hosts
echo "19.4.3.17 twitter.com" >> /etc/hosts
echo "19.4.3.9 webserver.dmz" >> /etc/hosts
echo "19.4.3.2 internal.lan" >> /etc/hosts

service dnsmasq restart

cat > /etc/squid/conf.d/00-custom.conf << 'EOF'
http_port 3128 intercept
http_port 127.0.0.1:3129

acl localnet src 19.4.3.0/29
http_access allow localnet
http_access deny all

url_rewrite_program /usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf
url_rewrite_children 5

cache deny all
EOF

cat > /etc/squidguard/squidGuard.conf << 'EOF'
dbhome /var/lib/squidguard/db
logdir /var/log/squid

src lan {
    ip 19.4.3.0/29
}

time workhours {
    weekly mtwhf 08:00-12:00
    weekly mtwhf 14:00-18:00
}

dest porn {
    domainlist porn/domains
    urllist porn/urls
}

dest social {
    domainlist social/domains
    urllist social/urls
}

acl {
    lan within workhours {
        pass !porn !social all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    lan {
        pass !porn all
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }

    default {
        pass none
        redirect http://19.4.3.3/cgi-bin/squidGuard.cgi?clientaddr=%a&clientname=%n&clientuser=%i&clientgroup=%s&targetgroup=%t&url=%u
    }
}
EOF

mkdir -p /var/lib/squidguard/db/porn
cat > /var/lib/squidguard/db/porn/domains << 'EOF'
pornhub.com
xvideos.com
xnxx.com
redtube.com
youporn.com
EOF
: > /var/lib/squidguard/db/porn/urls

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
: > /var/lib/squidguard/db/social/urls

squidGuard -b -d -C all
chown -R proxy:proxy /var/lib/squidguard/db
chown -R proxy:proxy /var/log/squid
chmod -R 755 /var/lib/squidguard/db

squid -k parse
service squid restart || true

if [[ -x /usr/local/bin/apply_tc_per_ip.sh ]]; then
    /usr/local/bin/apply_tc_per_ip.sh
else
    echo "[firewall_startup] WARNING: /usr/local/bin/apply_tc_per_ip.sh manquant ou non exécutable."
fi

exec "$@"