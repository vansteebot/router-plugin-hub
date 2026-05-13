#!/bin/sh
# /usr/share/shadowsocksr/dns-flush.sh
# Wipe all router-side DNS caches. Called by the LuCI "清理 DNS 缓存并生效"
# button (controller action act_flush_dns) before the rebuild is queued.
#
# Why this is its own step instead of part of rebuild:
#   chinadns-ng holds its cache in RAM (cache-stale defaults to 86400s = 1 day).
#   GeoDNS-aware Chinese sites (baidu.com, qq.com, taobao.com, etc.) return the
#   wrong CDN IPs when queried from a non-CN source IP — which is exactly what
#   happens while the proxy exit is overseas. Once those wrong answers land in
#   the cache, even switching back to a domestic exit doesn't help: the cache
#   keeps serving them for up to 24 hours. A normal SSR rebuild that respawns
#   chinadns-ng would still re-read any persistent cache files on disk. We wipe
#   both the files AND the in-memory state by killing the processes outright;
#   the caller then queues a rebuild that brings them back with empty caches.

set +e
LOGTAG="dns-flush"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }
log()   { echo "[$LOGTAG] $(stamp) $*"; }

log "starting cache wipe"

# 1. Remove any persistent chinadns-ng cache files on disk
find /tmp /var -name 'chinadns*cache*' 2>/dev/null -exec rm -f {} \; -exec echo "  removed: {}" \;

# 2. Kill chinadns-ng so its in-memory cache vanishes. The follow-up
#    sync-apply rebuild that the caller will trigger spawns fresh ones.
PIDS=$(pgrep -f chinadns-ng 2>/dev/null)
if [ -n "$PIDS" ]; then
    log "killing chinadns-ng PIDs: $PIDS"
    for P in $PIDS; do
        kill "$P" 2>/dev/null
    done
    sleep 1
    # Anything that didn't die gracefully: force.
    pkill -9 -f chinadns-ng 2>/dev/null
    killall -q -9 chinadns-ng 2>/dev/null
fi

# 3. Restart dnsmasq to flush its own LRU cache.
log "restarting dnsmasq to flush its cache"
/etc/init.d/dnsmasq restart >/dev/null 2>&1

log "done — caller should now queue a sync-apply rebuild to respawn chinadns-ng"
exit 0
