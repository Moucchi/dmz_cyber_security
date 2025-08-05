#! /bin/bash
docker build -t ubuntu_client -f dmz_client . 
docker build -t ubuntu_wan -f dmz_wan . 
docker build -t ubuntu_webserver -f dmz_webserver . 
docker build -t ubuntu_firewall -f firewall .
docker build -t ubuntu_lan_webserver -f lan_webserver .
