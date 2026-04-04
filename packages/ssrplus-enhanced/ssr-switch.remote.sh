#!/bin/sh /etc/rc.common
#
# Controlled SSR Plus+ auto switch monitor.
# Replaces the old restart-looping ssr-switch behavior.
#

. $IPKG_INSTROOT/etc/init.d/shadowsocksr

LOCK_FILE="/var/lock/ssr-switch.lock"
STATE_FILE="/tmp/ssrplus-auto-switch.state"
SYNC_LOCK_FILE="/var/lock/ssrplus-sync-apply.lock"
SYNC_SCRIPT="/usr/share/shadowsocksr/sync-apply.lua"
COMPUTER_HOSTNAME="DESKTOP-CAN8CYE"
COMPUTER_MAC="08:BF:B8:EE:DE:58"
COMPUTER_IP="192.168.8.159"

CYCLE_TIME=30
PROBE_TIMEOUT=3
FAIL_THRESHOLD=4
PROBE_HOST="www.google.com"
PROBE_PORT="80"
WINDOW_SECONDS=300
WINDOW_THRESHOLD=10
COOLDOWN_SECONDS=300
FAIL_COUNT=0
WINDOW_FAIL_COUNT=0
FAIL_TIMESTAMPS=""
LAST_PROBE="idle"
LAST_ACTION="idle"
LAST_SWITCH_AT=0
LAST_SWITCH_TARGET=""
LAST_SWITCH_REASON=""
CURRENT_SERVER=""
CANDIDATES=""

normalize_seconds() {
	local value="$1"
	value="${value%s}"
	case "$value" in
		""|*[!0-9]*)
			echo "30"
			;;
		*)
			echo "$value"
			;;
	esac
}

load_runtime_config() {
	CYCLE_TIME="$(normalize_seconds "${1:-$(uci_get_by_type global switch_time 30)}")"
	PROBE_TIMEOUT="$(normalize_seconds "${2:-$(uci_get_by_type global switch_timeout 3)}")"
	FAIL_THRESHOLD="$(normalize_seconds "$(uci_get_by_type global switch_try_count 4)")"
	PROBE_HOST="$(uci_get_by_type global switch_probe_host www.google.com)"
	PROBE_PORT="$(normalize_seconds "$(uci_get_by_type global switch_probe_port 80)")"
	WINDOW_SECONDS="$(normalize_seconds "$(uci_get_by_type global switch_window_seconds 300)")"
	WINDOW_THRESHOLD="$(normalize_seconds "$(uci_get_by_type global switch_window_failures 10)")"
	COOLDOWN_SECONDS="$(normalize_seconds "$(uci_get_by_type global switch_cooldown 300)")"
	[ "$FAIL_THRESHOLD" -ge 0 ] 2>/dev/null || FAIL_THRESHOLD=4
	[ "$PROBE_TIMEOUT" -gt 0 ] 2>/dev/null || PROBE_TIMEOUT=3
	[ "$PROBE_PORT" -gt 0 ] 2>/dev/null || PROBE_PORT=80
	[ "$WINDOW_SECONDS" -ge 0 ] 2>/dev/null || WINDOW_SECONDS=300
	[ "$WINDOW_THRESHOLD" -ge 0 ] 2>/dev/null || WINDOW_THRESHOLD=10
	[ "$COOLDOWN_SECONDS" -ge 0 ] 2>/dev/null || COOLDOWN_SECONDS=300
}

load_state() {
	FAIL_COUNT=0
	WINDOW_FAIL_COUNT=0
	FAIL_TIMESTAMPS=""
	LAST_PROBE="idle"
	LAST_ACTION="idle"
	LAST_SWITCH_AT=0
	LAST_SWITCH_TARGET=""
	LAST_SWITCH_REASON=""
	CURRENT_SERVER=""
	if [ -f "$STATE_FILE" ]; then
		. "$STATE_FILE" 2>/dev/null || true
	fi
}

save_state() {
	cat >"$STATE_FILE.tmp" <<EOF
FAIL_COUNT=$FAIL_COUNT
WINDOW_FAIL_COUNT=$WINDOW_FAIL_COUNT
FAIL_TIMESTAMPS=$FAIL_TIMESTAMPS
LAST_PROBE=$LAST_PROBE
LAST_ACTION=$LAST_ACTION
LAST_SWITCH_AT=$LAST_SWITCH_AT
LAST_SWITCH_TARGET=$LAST_SWITCH_TARGET
LAST_SWITCH_REASON=$LAST_SWITCH_REASON
CURRENT_SERVER=$CURRENT_SERVER
PROBE_HOST=$PROBE_HOST
PROBE_PORT=$PROBE_PORT
INTERVAL=$CYCLE_TIME
THRESHOLD=$FAIL_THRESHOLD
WINDOW_SECONDS=$WINDOW_SECONDS
WINDOW_THRESHOLD=$WINDOW_THRESHOLD
COOLDOWN_SECONDS=$COOLDOWN_SECONDS
EOF
	mv "$STATE_FILE.tmp" "$STATE_FILE"
}

auto_switch_enabled() {
	[ "$(uci_get_by_type global enable_switch 0)" = "1" ]
}

switch_in_progress() {
	[ -f "$SYNC_LOCK_FILE" ]
}

rebuild_window_failures() {
	local now="${1:-$(date +%s)}"
	local fresh=""
	local count=0
	local ts=""
	local old_ifs="$IFS"

	IFS=','
	for ts in $FAIL_TIMESTAMPS; do
		[ -n "$ts" ] || continue
		case "$ts" in
			*[!0-9]*)
				continue
				;;
		esac
		if [ "$WINDOW_SECONDS" -le 0 ] 2>/dev/null || [ $((now - ts)) -le "$WINDOW_SECONDS" ] 2>/dev/null; then
			fresh="${fresh}${fresh:+,}$ts"
			count=$((count + 1))
		fi
	done
	IFS="$old_ifs"

	FAIL_TIMESTAMPS="$fresh"
	WINDOW_FAIL_COUNT="$count"
}

record_failure() {
	local now="${1:-$(date +%s)}"
	rebuild_window_failures "$now"
	if [ "$WINDOW_SECONDS" -gt 0 ] 2>/dev/null && [ "$WINDOW_THRESHOLD" -gt 0 ] 2>/dev/null; then
		FAIL_TIMESTAMPS="${FAIL_TIMESTAMPS}${FAIL_TIMESTAMPS:+,}$now"
		WINDOW_FAIL_COUNT=$((WINDOW_FAIL_COUNT + 1))
	fi
}

reset_consecutive_failures() {
	FAIL_COUNT=0
}

reset_all_failures() {
	FAIL_COUNT=0
	WINDOW_FAIL_COUNT=0
	FAIL_TIMESTAMPS=""
}

cooldown_active() {
	local now="${1:-$(date +%s)}"
	if [ "$COOLDOWN_SECONDS" -le 0 ] 2>/dev/null || [ "$LAST_SWITCH_AT" -le 0 ] 2>/dev/null; then
		return 1
	fi
	[ $((now - LAST_SWITCH_AT)) -lt "$COOLDOWN_SECONDS" ] 2>/dev/null
}

probe_current_proxy() {
	/usr/bin/ssr-check "$PROBE_HOST" "$PROBE_PORT" "$PROBE_TIMEOUT" 1 >/dev/null 2>&1
}

collect_candidate() {
	local section="$1"
	[ "$(uci_get_by_name "$section" switch_enable 0)" = "1" ] || return 0
	CANDIDATES="$CANDIDATES $section"
}

build_candidates() {
	CANDIDATES=""
	config_load "$NAME"
	config_foreach collect_candidate servers
}

pick_next_candidate() {
	local current="$1"
	local first=""
	local found_current=0
	local candidate=""

	for section in $CANDIDATES; do
		[ -n "$first" ] || first="$section"
		if [ "$found_current" = "1" ] && [ "$section" != "$current" ]; then
			candidate="$section"
			break
		fi
		[ "$section" = "$current" ] && found_current=1
	done

	if [ -z "$candidate" ]; then
		if printf ' %s ' "$CANDIDATES" | grep -q " $current "; then
			for section in $CANDIDATES; do
				if [ "$section" != "$current" ]; then
					candidate="$section"
					break
				fi
			done
		else
			candidate="$first"
		fi
	fi

	[ -n "$candidate" ] || return 1
	printf '%s' "$candidate"
}

queue_switch() {
	local target="$1"
	local reason="${2:-threshold}"
	local now="${3:-$(date +%s)}"
	local alias="$(uci_get_by_name "$target" alias "$target")"

	uci set "$NAME.@global[0].global_server=$target"
	uci commit "$NAME"

	reset_all_failures
	LAST_PROBE="fail"
	LAST_ACTION="queued"
	LAST_SWITCH_AT="$now"
	LAST_SWITCH_TARGET="$target"
	LAST_SWITCH_REASON="$reason"
	CURRENT_SERVER="$target"
	save_state

	echolog "Controlled auto switch queued -> ${alias} (${reason})"
	logger -t "$NAME" "Controlled auto switch queued -> ${alias} (${reason})"
	( /usr/bin/lua "$SYNC_SCRIPT" "autoswitch:$target" "$COMPUTER_HOSTNAME" "$COMPUTER_MAC" "$COMPUTER_IP" >/tmp/ssrplus-sync-apply-bg.log 2>&1 ) &
}

start() {
	[ -f "$LOCK_FILE" ] && exit 2
	echo $$ > "$LOCK_FILE"
	trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

	load_runtime_config "$1" "$2"
	load_state
	CURRENT_SERVER="$(uci_get_by_type global global_server nil)"
	save_state
	echolog "Controlled auto switch started: interval=${CYCLE_TIME}s threshold=${FAIL_THRESHOLD} probe=${PROBE_HOST}:${PROBE_PORT}"

	while [ "1" = "1" ]; do
		auto_switch_enabled || {
			LAST_ACTION="disabled"
			save_state
			exit 0
		}

		if switch_in_progress; then
			LAST_ACTION="busy"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		load_runtime_config
		build_candidates
		PREVIOUS_SERVER="$CURRENT_SERVER"
		CURRENT_SERVER="$(uci_get_by_type global global_server nil)"
		if [ "$PREVIOUS_SERVER" != "$CURRENT_SERVER" ]; then
			reset_all_failures
			LAST_ACTION="server_changed"
			save_state
		fi

		if [ "$CURRENT_SERVER" = "nil" ] || [ -z "$CURRENT_SERVER" ]; then
			reset_all_failures
			LAST_ACTION="disabled"
			LAST_PROBE="idle"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		if [ -z "$CANDIDATES" ]; then
			reset_all_failures
			LAST_ACTION="no_candidates"
			LAST_PROBE="idle"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		NOW="$(date +%s)"
		rebuild_window_failures "$NOW"

		if probe_current_proxy; then
			if [ "$FAIL_COUNT" -gt 0 ]; then
				echolog "Controlled auto switch recovered on current node $(uci_get_by_name "$CURRENT_SERVER" alias "$CURRENT_SERVER")"
			fi
			reset_consecutive_failures
			LAST_PROBE="ok"
			LAST_ACTION="healthy"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		FAIL_COUNT=$((FAIL_COUNT + 1))
		record_failure "$NOW"
		LAST_PROBE="fail"
		LAST_ACTION="probing"
		save_state
		echolog "Controlled auto switch probe failed ${FAIL_COUNT}/${FAIL_THRESHOLD}, window ${WINDOW_FAIL_COUNT}/${WINDOW_THRESHOLD} on $(uci_get_by_name "$CURRENT_SERVER" alias "$CURRENT_SERVER")"

		SWITCH_REASON=""
		if [ "$FAIL_THRESHOLD" -gt 0 ] 2>/dev/null && [ "$FAIL_COUNT" -ge "$FAIL_THRESHOLD" ] 2>/dev/null; then
			SWITCH_REASON="consecutive"
		elif [ "$WINDOW_THRESHOLD" -gt 0 ] 2>/dev/null && [ "$WINDOW_FAIL_COUNT" -ge "$WINDOW_THRESHOLD" ] 2>/dev/null; then
			SWITCH_REASON="window"
		fi

		if [ -z "$SWITCH_REASON" ]; then
			sleep "$CYCLE_TIME"
			continue
		fi

		if cooldown_active "$NOW"; then
			LAST_ACTION="cooldown"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		NEXT_SERVER="$(pick_next_candidate "$CURRENT_SERVER")" || NEXT_SERVER=""
		if [ -z "$NEXT_SERVER" ] || [ "$NEXT_SERVER" = "$CURRENT_SERVER" ]; then
			reset_all_failures
			LAST_ACTION="single_candidate"
			save_state
			sleep "$CYCLE_TIME"
			continue
		fi

		queue_switch "$NEXT_SERVER" "$SWITCH_REASON" "$NOW"
		sleep "$CYCLE_TIME"
	done
}
