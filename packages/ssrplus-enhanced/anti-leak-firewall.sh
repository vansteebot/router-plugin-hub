#!/bin/sh
#
# anti-leak-firewall.sh
#
# Add 4 firewall traffic rules to block well-known LAN-to-WAN leak channels
# (WebRTC STUN/TURN + QUIC) so that a misbehaving browser cannot expose the
# user's real direct IP while the router is supposed to be routing
# everything through the proxy.
#
# Rule set (mirrors the screenshotted GL-BE3600 panel exactly):
#
#   Anti-Leak 1: Block QUIC UDP 443         lan -> wan  udp  port 443
#   Anti-Leak 2: Block QUIC UDP 80          lan -> wan  udp  port 80
#   Anti-Leak 3: Block WebRTC STUN/TURN UDP lan -> wan  udp  3478 3479 5349 5350 19302-19309
#   Anti-Leak 4: Block WebRTC STUN/TURN TCP lan -> wan  tcp  3478 5349
#
# All rules use family=any (IPv4 + IPv6) and target=REJECT so the leak attempt
# fails fast instead of timing out.
#
# Idempotent: any existing rules whose name starts with "Anti-Leak " are
# removed first, so re-running the script never duplicates rules.
#
# Verify after install:
#   https://webrtcleakshield.org/   (the page should NOT see your real IP)
#

set -e

log() { printf '[Anti-Leak] %s\n' "$*"; }

# -------------------------------------------------------------------- 1
# Remove any existing rules whose name starts with "Anti-Leak " (idempotent).
# We re-scan after each delete because uci section names shift on delete.
log "Removing any existing Anti-Leak* rules (idempotent)..."
while :; do
    removed=0
    # uci show firewall lists '.section=rule' lines; we extract section names
    # and check each one's .name field.
    sections=$(uci -q show firewall | awk -F'=' '/=rule$/ {gsub("firewall\\.", "", $1); print $1}')
    for sect in $sections; do
        name=$(uci -q get "firewall.$sect.name") || continue
        case "$name" in
            "Anti-Leak "*)
                uci delete "firewall.$sect" 2>/dev/null && {
                    log "  deleted: $sect ($name)"
                    removed=1
                    break
                }
                ;;
        esac
    done
    [ "$removed" = "0" ] && break
done

# -------------------------------------------------------------------- 2
# Helper: add one REJECT rule (lan -> wan, family=any).
add_rule() {
    name="$1"; proto="$2"; port="$3"
    uci add firewall rule >/dev/null
    uci set "firewall.@rule[-1].name=$name"
    uci set "firewall.@rule[-1].src=lan"
    uci set "firewall.@rule[-1].dest=wan"
    uci set "firewall.@rule[-1].proto=$proto"
    uci set "firewall.@rule[-1].dest_port=$port"
    uci set "firewall.@rule[-1].target=REJECT"
    uci set "firewall.@rule[-1].family=any"
    uci set "firewall.@rule[-1].enabled=1"
    log "  added: $name  ($proto $port)"
}

log "Adding 4 anti-leak rules..."
add_rule "Anti-Leak 1: Block QUIC UDP 443"          "udp" "443"
add_rule "Anti-Leak 2: Block QUIC UDP 80"           "udp" "80"
add_rule "Anti-Leak 3: Block WebRTC STUN/TURN UDP"  "udp" "3478 3479 5349 5350 19302-19309"
add_rule "Anti-Leak 4: Block WebRTC STUN/TURN TCP"  "tcp" "3478 5349"

# -------------------------------------------------------------------- 3
# Commit + reload (no restart needed; fw4 hot-reloads cleanly).
log "Committing UCI + reloading firewall..."
uci commit firewall
if ! /etc/init.d/firewall reload >/dev/null 2>&1; then
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
fi

log "Done. The 4 rules should now appear in LuCI -> 网络 -> 防火墙 -> 通信规则."
log "Verify your browser no longer leaks via WebRTC / QUIC:"
log "  https://webrtcleakshield.org/"
log "The page should ONLY show your proxy exit IP (or nothing)."
