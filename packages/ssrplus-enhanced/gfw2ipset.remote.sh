#!/bin/sh

. $IPKG_INSTROOT/etc/init.d/shadowsocksr

if command -v nft >/dev/null 2>&1; then
    nft_support=1
fi

ensure_dnsmasq_dir() {
	[ -d "$TMP_DNSMASQ_PATH" ] || mkdir -p "$TMP_DNSMASQ_PATH"
}

netflix() {
	if [ -f "$TMP_DNSMASQ_PATH/gfw_list.conf" ]; then
		for line in $(cat /etc/ssrplus/netflix.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/gfw_list.conf; done
		for line in $(cat /etc/ssrplus/netflix.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/gfw_base.conf; done
	fi
	if [ "$nft_support" = "1" ]; then
		# 移除 ipset
		cat /etc/ssrplus/netflix.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1#$1\nnftset=\/&\/4#inet#ss_spec#netflix/" >$TMP_DNSMASQ_PATH/netflix_forward.conf
	else
		cat /etc/ssrplus/netflix.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1#$1\nipset=\/&\/netflix/" >$TMP_DNSMASQ_PATH/netflix_forward.conf
	fi
}
ensure_dnsmasq_dir
if [ "$(uci_get_by_type global run_mode router)" == "oversea" ]; then
	cp -rf /etc/ssrplus/oversea_list.conf $TMP_DNSMASQ_PATH/
else
	cp -rf /etc/ssrplus/gfw_list.conf $TMP_DNSMASQ_PATH/
	cp -rf /etc/ssrplus/gfw_base.conf $TMP_DNSMASQ_PATH/
fi

if [ "$nft_support" = "1" ]; then
    # 移除 ipset 指令
    for conf_file in gfw_base.conf gfw_list.conf; do
        if [ -f "$TMP_DNSMASQ_PATH/$conf_file" ]; then
            sed -i 's|ipset=/\([^/]*\)/\([^[:space:]]*\)|nftset=/\1/4#inet#ss_spec#\2|g' "$TMP_DNSMASQ_PATH/$conf_file"
        fi
    done
fi

if [ "$(uci_get_by_type global netflix_enable 0)" == "1" ]; then
	# 只有开启 NetFlix分流 才需要取值
	SHUNT_SERVER=$(uci_get_by_type global netflix_server nil)
else
	# 没有开启 设置为 nil
	SHUNT_SERVER=nil
fi
case "$SHUNT_SERVER" in
nil)
	rm -f $TMP_DNSMASQ_PATH/netflix_forward.conf
	;;
$(uci_get_by_type global global_server nil) | $switch_server | same)
	netflix $dns_port
	;;
*)
	netflix $tmp_shunt_dns_port
	;;
esac

# 单次 awk 扫描过滤 black/white/deny：
# - 避免对大文件反复 sed -i（gfw_list.conf 可达数万行时会长时间卡住/占用 CPU）
# - 避免 tmpfs 上 sed -i 临时文件 rename 竞争导致 dnsmasq 读不到配置
drop_listed_domains() {
	local conf_file="$1"
	[ -f "$conf_file" ] || return 0
	local tmp
	tmp="$(mktemp /tmp/ssrplus-gfw.XXXXXX)" || return 0
	awk '
	function load(listfile, line) {
		while ((getline line < listfile) > 0) {
			if (line ~ /^#/ || line == "")
				continue
			n++
			pat[n] = line
		}
		close(listfile)
	}
	BEGIN {
		n = 0
		load("/etc/ssrplus/black.list")
		load("/etc/ssrplus/white.list")
		load("/etc/ssrplus/deny.list")
	}
	{
		for (i = 1; i <= n; i++) {
			if (index($0, pat[i]) > 0)
				next
		}
		print
	}
	' "$conf_file" >"$tmp" || { rm -f "$tmp"; return 0; }
	ensure_dnsmasq_dir
	mv -f "$tmp" "$conf_file"
}

ensure_dnsmasq_dir
drop_listed_domains "$TMP_DNSMASQ_PATH/gfw_list.conf"
drop_listed_domains "$TMP_DNSMASQ_PATH/gfw_base.conf"

# 此处直接使用 cat 因为有 sed '/#/d' 删除了 数据
if [ "$nft_support" = "1" ]; then
	ensure_dnsmasq_dir
	cat /etc/ssrplus/black.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1#$dns_port\nnftset=\/&\/4#inet#ss_spec#blacklist/" >$TMP_DNSMASQ_PATH/blacklist_forward.conf
	cat /etc/ssrplus/white.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1\nnftset=\/&\/4#inet#ss_spec#whitelist/" >$TMP_DNSMASQ_PATH/whitelist_forward.conf
else
	ensure_dnsmasq_dir
	cat /etc/ssrplus/black.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1#$dns_port\nipset=\/&\/blacklist/" >$TMP_DNSMASQ_PATH/blacklist_forward.conf
	cat /etc/ssrplus/white.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/server=\/&\/127.0.0.1\nipset=\/&\/whitelist/" >$TMP_DNSMASQ_PATH/whitelist_forward.conf
fi
ensure_dnsmasq_dir
cat /etc/ssrplus/deny.list | sed '/^$/d' | sed '/#/d' | sed "/.*/s/.*/address=\/&\//" >$TMP_DNSMASQ_PATH/denylist.conf

if [ "$(uci_get_by_type global adblock 0)" == "1" ]; then
	cp -f /etc/ssrplus/ad.conf $TMP_DNSMASQ_PATH/
	if [ -f "$TMP_DNSMASQ_PATH/ad.conf" ]; then
		for line in $(cat /etc/ssrplus/black.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
		for line in $(cat /etc/ssrplus/white.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
		for line in $(cat /etc/ssrplus/deny.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
		for line in $(cat /etc/ssrplus/netflix.list); do sed -i "/$line/d" $TMP_DNSMASQ_PATH/ad.conf; done
	fi
else
	rm -f $TMP_DNSMASQ_PATH/ad.conf
fi
