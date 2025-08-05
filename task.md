# <u>Sujet : Mise en place d’une architecture DMZ via GNS3 et Docker</u>
## Introduction
Ce TP a pour objectif de mettre en pratique les notions liées à la défense périmétrique d’un système
d’information à travers la mise en place d’une <b>zone démilitarisée (DMZ)</b>. Les étudiants devront utiliser
GNS3 pour la création de la topologie réseau, et <b>Docker</b> ou des images de VM légères (Linux) pour le
déploiement des machines virtuelles.

ce TP vise à renforcer les compétences techniques en :
- Conception d’une architecture réseau sécurisée avec DMZ
- Mise en place de règles de ltrage et de NAT,
  Déploiement de solutions de détection/prévention des intrusions,
- Analyse de logs et validation de la politique de sécurité

## Instructions Générales 
- Travail en groupe de 2 à 3 étudiants.
- L’utilisation de GNS3 est obligatoire pour créer la topologie.
- Chaque groupe devra fournir un rapport PDF contenant :
  - Introduction
  - Méthodologie
  - Captures d’écran
  - Résultats des tests
  - Analyse et conclusion
- Toutes les congurations doivent être justiées (chiers de conf à joindre).

## Objectif Technique
Mettre en place une architecture réseau simulant une entreprise avec DMZ en vue de sécuriser les services
exposés au public tout en protégeant le réseau interne.

## Topologie à réaliser (obligatoire) 
- Le <b>pare-feu</b> aura 3 interfaces : vers WAN (Internet), vers DMZ et vers LAN.
- la <b>DMZ</b> contient un serveur web (Apache ou Nginx).
- Le <b>LAN</b> contient une ou plusieurs machines clientes (Linux desktop).
- Le <b>WAN</b> est une machine simulant un accès Internet externe.
- Des <b>switchs GNS3</b> doivent être utilisés pour relier les machines entre elles dans chaque sous-réseau
  (WAN, DMZ, LAN).

## Services et Comportements Attendus
1. <b>Pare-feu</b> : configurez avec <i>iptables</i> :
   - Autoriser HTTP, HTTPS, SSH vers la DMZ (depuis WAN et LAN)
   - Bloquer tout autre port ou protocole par défaut
   - Bloquer l’accès du WAN vers le LAN
   - Autoriser le LAN à sortir vers l’extérieur via NAT
   - Bloquer les sites pornographiques (SquidGuard ou autre blacklist)
   - Bloquer l’accès à Facebook et YouTube pendant les heures de travail (8h–12h, 14h–18h)
   - Limiter la bande passante à 500 Ko/s par machine LAN
   
2. <b>Serveur Web (DMZ) :</b>
   - Accessible en HTTP/HTTPS depuis WAN et LAN
   - Ne peut initier aucune connexion sortante

3. <b>Surveillance IDS avec Snort :</b>
   - Détecter : scan de ports, attaques courantes, connexions anormales
   - ournaliser et expliquer les alertes générées

## Tests à Réaliser
- ✅ WAN peut accéder à la page web de la DMZ.
- ❌ WAN ne peut pas ping ou accéder au LAN.
- ✅ LAN peut accéder à Internet et à la DMZ.
- ❌ Serveur web ne peut pas sortir sur Internet.
- ❌ Accès à Facebook/YouTube bloqués pendant les heures de travail.
- ❌ Accès à sites pour adultes bloqué depuis le LAN.
- ✅ Snort doit détecter une tentative de scan de ports depuis WAN.
## Livrables attendus
- Schéma du réseau GNS3 avec captures d’écran.
- Conguration du pare-feu (chiers iptables, exports pfSense...)
- Journal Snort avec analyse d’une alerte
- Justication des règles NAT et de ltrage
- Rapport PDF complet
