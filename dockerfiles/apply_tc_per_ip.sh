#!/usr/bin/env bash
# Applique une limite de 500 ko/s (~4000 kbit/s) PAR HÔTE LAN (download + upload)
# en créant des classes HTB par IP + fq_codel.
# Usage: ./apply_tc_per_ip.sh
set -euo pipefail

LAN_NET="19.4.3.0/29"
LAN_BASE="19.4.3"
FIREWALL_IP_SUFFIX=3        # Suffixe (dernier octet) de l'IP du firewall sur le LAN
PER_HOST_RATE="4000kbit"    # ≈ 500 ko/s
BURST="25k"                 # Burst raisonnable (ajuster si besoin)
CEIL="${PER_HOST_RATE}"

# Plage : /29 => .1 à .6 utilisables (0 = réseau, 7 = broadcast)
LAN_HOST_SUFFIX_START=1
LAN_HOST_SUFFIX_END=6

# Interfaces (adapter si tu changes la config)
LAN_IF="eth1"   # Vers les hôtes LAN (download shaping: match dst)
WAN_IF="eth0"   # Sortie vers WAN (upload shaping: match src)
DMZ_IF="eth2"   # Sortie vers DMZ (upload shaping: match src)

# Active un logging simple
log() { echo "[apply_tc_per_ip] $*"; }

# Supprimer qdisc existant si besoin (désactivé par défaut pour être idempotent)
RESET=${RESET_TC:-0}
if [[ "$RESET" == "1" ]]; then
  for IF in "$LAN_IF" "$WAN_IF" "$DMZ_IF"; do
    tc qdisc del dev "$IF" root 2>/dev/null || true
  done
fi

add_root_htb() {
  local IFACE=$1
  if ! tc qdisc show dev "$IFACE" | grep -q "htb 1:" ; then
    log "Ajout root HTB sur $IFACE"
    tc qdisc add dev "$IFACE" root handle 1: htb default 999
    # Classe 'catch-all' (faible) si un paquet ne matche pas (optionnel)
    tc class add dev "$IFACE" parent 1: classid 1:999 htb rate 128kbit ceil 128kbit
    tc qdisc add dev "$IFACE" parent 1:999 fq_codel
  else
    log "HTB déjà présent sur $IFACE, on réutilise."
  fi
}

add_per_ip_classes() {
  local IFACE=$1
  local MODE=$2   # 'src' ou 'dst'
  local FILTER_FIELD
  case "$MODE" in
    src) FILTER_FIELD="src" ;;
    dst) FILTER_FIELD="dst" ;;
    *) echo "MODE invalide: $MODE" >&2; exit 1 ;;
  esac

  add_root_htb "$IFACE"

  for (( i=LAN_HOST_SUFFIX_START; i<=LAN_HOST_SUFFIX_END; i++ )); do
    if [[ $i -eq $FIREWALL_IP_SUFFIX ]]; then
      continue  # on ne limite pas le firewall lui-même
    fi
    local IP="${LAN_BASE}.${i}"
    local CLASSID_HEX
    # ClasseID: 1:1XX (XX = dernier octet en hex ou décimal). On garde simple en décimal concaténé.
    CLASSID_HEX="1:1${i}"

    # Si la classe n'existe pas déjà
    if ! tc class show dev "$IFACE" | grep -q "class htb ${CLASSID_HEX}"; then
      log "Ajout classe pour IP $IP sur $IFACE (mode=$MODE) rate=$PER_HOST_RATE"
      tc class add dev "$IFACE" parent 1: classid "${CLASSID_HEX}" htb rate "$PER_HOST_RATE" ceil "$CEIL" burst "$BURST"
      tc qdisc add dev "$IFACE" parent "${CLASSID_HEX}" fq_codel
    fi

    # Filtre u32
    # On teste existence via grep sur 'match <hexIP>'
    local HEXIP
    # Convertit IP en hex continu (pas strictement nécessaire pour grep, on va matcher la ligne entière autrement)
    HEXIP=$(printf '%02x%02x%02x%02x' ${LAN_BASE//./ } | sed "s/${LAN_BASE//./ }/${LAN_BASE//./ }/") || true
    # (Simplification : on ne s'appuie pas sur HEXIP dans grep, juste sur l'adresse)
    if ! tc filter show dev "$IFACE" parent 1: | grep -q "flowid ${CLASSID_HEX}.* ${FILTER_FIELD} ${IP}"; then
      log "Ajout filtre u32 pour $FILTER_FIELD $IP -> ${CLASSID_HEX} sur $IFACE"
      tc filter add dev "$IFACE" parent 1: protocol ip prio 1 u32 \
        match ip $FILTER_FIELD "$IP"/32 \
        flowid "${CLASSID_HEX}"
    fi
  done
}

log "=== Application des limites par IP (HTB) ==="
log "Plafond par hôte: $PER_HOST_RATE"

# DOWNLOAD (vers LAN) : classer par destination sur eth1
add_per_ip_classes "$LAN_IF" "dst"

# UPLOAD (depuis LAN) : classer par source sur eth0 (WAN) et eth2 (DMZ)
add_per_ip_classes "$WAN_IF" "src"
add_per_ip_classes "$DMZ_IF" "src"

log "Terminé."