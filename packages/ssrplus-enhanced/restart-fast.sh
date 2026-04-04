#!/bin/sh

set -eu

run_restart() {
	killall -q -9 ss-redir sslocal obfs-local dns2tcp dns2socks dns2socks-rust mosdns dnsproxy chinadns-ng ssr-switch >/dev/null 2>&1 || true
	sleep 1
	/etc/init.d/shadowsocksr restart >/dev/null 2>&1
	killall -HUP dnsmasq >/dev/null 2>&1 || true
}

if [ "${1:-}" = "--bg" ]; then
	(run_restart) &
	exit 0
fi

run_restart
