local uci = require("luci.model.uci").cursor()
local jsonc = require("luci.jsonc")
local nixio = require("nixio")

local STATUS_FILE = "/tmp/ssrplus-action-status.json"
local LOG_FILE = "/tmp/ssrplus-sync-apply.log"
local LOCK_FILE = "/var/lock/ssrplus-sync-apply.lock"

local function trim(value)
	value = tostring(value or "")
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(value)
	value = tostring(value or "")
	value = value:gsub("'", [['"'"']])
	return "'" .. value .. "'"
end

local function exec(cmd)
	local fp = io.popen(cmd .. " 2>/dev/null")
	if not fp then
		return ""
	end
	local data = fp:read("*a") or ""
	fp:close()
	return trim(data)
end

local function call(cmd)
	local ok, why, code = os.execute(cmd)
	if type(ok) == "number" then
		return ok
	end
	if ok == true then
		return 0
	end
	return tonumber(code) or 1
end

local function write_file(path, content)
	local fp = io.open(path, "w")
	if not fp then
		return false
	end
	fp:write(content)
	fp:close()
	return true
end

local function write_status(data)
	data.time = data.time or os.date("%Y-%m-%d %H:%M:%S")
	local encoded = jsonc.stringify(data) or "{}"
	write_file(STATUS_FILE, encoded)
	return data
end

local function acquire_lock()
	local existing = trim(exec("cat " .. shell_quote(LOCK_FILE)))
	if existing ~= "" and call("kill -0 " .. existing .. " >/dev/null 2>&1") == 0 then
		return false, existing
	end
	write_file(LOCK_FILE, tostring(nixio.getpid()))
	return true
end

local function release_lock()
	call("rm -f " .. shell_quote(LOCK_FILE) .. " >/dev/null 2>&1")
end

local function read_status()
	local fp = io.open(STATUS_FILE, "r")
	if not fp then
		return nil
	end
	local raw = fp:read("*a")
	fp:close()
	if not raw or raw == "" then
		return nil
	end
	return jsonc.parse(raw)
end

local function ensure_list(value)
	if type(value) == "table" then
		return value
	end
	if value == nil or value == "" then
		return {}
	end
	return { tostring(value) }
end

local function normalize_server_section(section)
	section = tostring(section or "")
	local index = section:match("^@servers%[(%d+)%]$")
	if not index then
		return section
	end
	index = tonumber(index)
	local current = 0
	local resolved = section
	uci:foreach("shadowsocksr", "servers", function(s)
		if current == index then
			resolved = s[".name"] or section
		end
		current = current + 1
	end)
	return resolved
end

local function get_active_node()
	local section = normalize_server_section(uci:get_first("shadowsocksr", "global", "global_server", "nil"))
	local alias = "停用"
	local server = ""
	local port = ""
	local plugin = ""
	if section and section ~= "" and section ~= "nil" then
		alias = uci:get("shadowsocksr", section, "alias") or alias
		server = uci:get("shadowsocksr", section, "server") or server
		port = uci:get("shadowsocksr", section, "server_port") or port
		plugin = uci:get("shadowsocksr", section, "plugin") or plugin
	end
	return {
		section = section,
		alias = alias,
		server = server,
		port = port,
		plugin = plugin
	}
end

local function get_public_ip(attempts, delay_seconds)
	local endpoints = {
		"https://api.ip.sb/ip",
		"https://api64.ipify.org",
		"https://ipv4.icanhazip.com"
	}
	attempts = tonumber(attempts) or 1
	delay_seconds = tonumber(delay_seconds) or 0
	for attempt = 1, attempts do
		for _, url in ipairs(endpoints) do
			local ip = exec("curl -4 -m 8 -fsSL " .. shell_quote(url))
			if ip ~= "" then
				return ip
			end
		end
		if attempt < attempts and delay_seconds > 0 then
			call("sleep " .. tostring(delay_seconds))
		end
	end
	return ""
end

local function extract_public_ipv4(text)
	text = tostring(text or "")
	return text:match("(%d+%.%d+%.%d+%.%d+)")
end

local function get_direct_public_ip()
	local endpoints = {
		"https://myip.ipip.net",
		"https://ddns.oray.com/checkip",
		"https://ip.3322.net"
	}
	for _, url in ipairs(endpoints) do
		local raw = exec("curl -4 -m 8 -fsSL " .. shell_quote(url))
		local ip = extract_public_ipv4(raw)
		if ip and ip ~= "" then
			return ip
		end
	end
	return ""
end

local function get_ipv6_state(mode_override)
	local global = uci:get_first("shadowsocksr", "global")
	local mode = trim(mode_override or (global and uci:get("shadowsocksr", global, "ipv6_mode") or "off"))
	if mode == "" then
		mode = "off"
	end
	local dnsmasq = uci:get_first("dhcp", "dnsmasq")
	local filter_aaaa = dnsmasq and uci:get("dhcp", dnsmasq, "filter_aaaa") or "0"
	local wan6_exists = uci:get("network", "wan6") ~= nil
	local wan6_disabled = uci:get("network", "wan6", "disabled") or "1"
	local wan6_proto = trim(uci:get("network", "wan6", "proto") or "")
	local lan_ip6assign = trim(uci:get("network", "lan", "ip6assign") or "")
	local lan_dhcpv6 = uci:get("dhcp", "lan", "dhcpv6") or "disabled"
	local lan_ra = uci:get("dhcp", "lan", "ra") or "disabled"
	local lan_supported = lan_ip6assign ~= "" and lan_ip6assign ~= "0"
	local enabled = wan6_disabled ~= "1" and lan_dhcpv6 ~= "disabled" and lan_ra ~= "disabled"

	local raw = exec("ifstatus wan6")
	local wan6_status = raw ~= "" and jsonc.parse(raw) or {}
	local function count(value)
		return type(value) == "table" and #value or 0
	end
	local wan6_online = wan6_status.up == true
		or count(wan6_status["ipv6-address"]) > 0
		or count(wan6_status["ipv6-prefix-assignment"]) > 0
		or count(wan6_status["ipv6-prefix"]) > 0
	local auto_supported = lan_supported and (wan6_exists or wan6_proto ~= "")
	local desired_enabled = mode == "manual" or (mode == "auto" and auto_supported)
	local mode_label = ({ off = "关闭", auto = "自动", manual = "手动开启" })[mode] or "关闭"
	local support_label
	if auto_supported then
		support_label = wan6_online and "WAN6 已在线" or "WAN6 待连接"
	else
		support_label = lan_supported and "等待 WAN6" or "LAN 不支持"
	end
	local summary_parts = { mode_label, enabled and "系统 IPv6 已开启" or "系统 IPv6 已关闭" }
	if mode == "auto" then
		table.insert(summary_parts, auto_supported and "可自动判断" or "自动判断不可用")
	end
	table.insert(summary_parts, filter_aaaa == "1" and "AAAA 过滤开启" or "AAAA 过滤关闭")
	table.insert(summary_parts, support_label)
	return {
		mode = mode,
		mode_label = mode_label,
		enabled = enabled,
		desired_enabled = desired_enabled,
		filter_aaaa = filter_aaaa == "1",
		status = table.concat(summary_parts, " / "),
		lan_supported = lan_supported,
		auto_supported = auto_supported,
		wan6_online = wan6_online,
		wan6_exists = wan6_exists,
		wan6_proto = wan6_proto
	}
end

local function ensure_wan6_section()
	if not uci:get("network", "wan6") then
		uci:section("network", "interface", "wan6", {
			proto = "dhcpv6",
			device = "@wan"
		})
	end
end

local function apply_ipv6_mode_config(mode_override)
	local mode = trim(mode_override or "off")
	if mode ~= "off" then
		ensure_wan6_section()
		uci:set("network", "wan6", "proto", "dhcpv6")
		uci:set("network", "wan6", "device", "@wan")
	end
	local ipv6 = get_ipv6_state(mode)
	if ipv6.desired_enabled then
		ensure_wan6_section()
		uci:set("network", "wan6", "disabled", "0")
		uci:set("dhcp", "lan", "dhcpv6", "server")
		uci:set("dhcp", "lan", "ra", "server")
		uci:set("dhcp", "lan", "ra_slaac", "1")
		uci:set("dhcp", "lan", "ra_default", "1")
	else
		if uci:get("network", "wan6") then
			uci:set("network", "wan6", "disabled", "1")
		end
		uci:set("dhcp", "lan", "dhcpv6", "disabled")
		uci:set("dhcp", "lan", "ra", "disabled")
		uci:set("dhcp", "lan", "ra_slaac", "0")
		uci:set("dhcp", "lan", "ra_default", "0")
	end
	local dnsmasq = uci:get_first("dhcp", "dnsmasq")
	if dnsmasq then
		uci:set("dhcp", dnsmasq, "filter_aaaa", "1")
	end
	uci:commit("network")
	uci:commit("dhcp")
	return get_ipv6_state(mode)
end

local function is_running(pattern)
	local count = exec("busybox ps -w | grep " .. shell_quote(pattern) .. " | grep -v grep | wc -l")
	return tonumber(count) and tonumber(count) > 0
end

local function dns_helper_name(mode)
	local mapping = {
		["1"] = "dns2tcp",
		["2"] = "dns2socks",
		["3"] = "dns2socks-rust",
		["4"] = "mosdns",
		["5"] = "dnsproxy",
		["6"] = "chinadns-ng",
	}
	return mapping[tostring(mode or "")]
end

local function resolve_ipv4(domain)
	if not domain or domain == "" then
		return ""
	end
	local output = exec("nslookup " .. shell_quote(domain) .. " 127.0.0.1")
	local answer = false
	for line in output:gmatch("[^\r\n]+") do
		if line:match("^Name:") or line:match("^[Nn]on%-authoritative answer:") then
			answer = true
		elseif answer then
			local value = line:match("Address[^:]*:%s*([0-9%.]+)")
			if value and value ~= "127.0.0.1" then
				return value
			end
		end
	end
	return ""
end

local function nft_bypass_sets()
	local sets = {}
	if call("nft list set inet ss_spec ss_spec_wan_ac_tcp >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac_tcp")
	end
	if call("nft list set inet ss_spec ss_spec_wan_ac_udp >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac_udp")
	end
	if #sets == 0 and call("nft list set inet ss_spec ss_spec_wan_ac >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac")
	end
	return sets
end

local function add_probe_bypass(target)
	if not target or target == "" or not target:match("^%d+%.%d+%.%d+%.%d+$") then
		return nil
	end
	local use_nft = call("command -v nft >/dev/null 2>&1") == 0
	if use_nft then
		local added = {}
		for _, set_name in ipairs(nft_bypass_sets()) do
			if call("nft add element inet ss_spec " .. set_name .. " { " .. target .. " } >/dev/null 2>&1") == 0 then
				table.insert(added, set_name)
			end
		end
		if #added > 0 then
			return { use_nft = true, target = target, sets = added }
		end
		return nil
	end
	if call("ipset add ss_spec_wan_ac " .. target .. " >/dev/null 2>&1") == 0 then
		return { use_nft = false, target = target }
	end
	return nil
end

local function remove_probe_bypass(state)
	if not state or not state.target or state.target == "" or not state.target:match("^%d+%.%d+%.%d+%.%d+$") then
		return
	end
	if state.use_nft then
		for _, set_name in ipairs(state.sets or {}) do
			call("nft delete element inet ss_spec " .. set_name .. " { " .. state.target .. " } >/dev/null 2>&1")
		end
	else
		call("ipset del ss_spec_wan_ac " .. state.target .. " >/dev/null 2>&1")
	end
end

local function parse_latency_ms(output)
	output = tostring(output or "")
	if output == "" then
		return nil
	end
	local value = output:match("time=([0-9%.]+)%s*ms")
		or output:match("time=([0-9%.]+)")
		or output:match("min/avg/max = [0-9%.]+/([0-9%.]+)/")
		or output:match("Avg rtt:%s*([0-9%.]+)ms")
	local latency = tonumber(value)
	if not latency or latency <= 0 then
		return nil
	end
	return math.floor(latency + 0.5)
end

local function requires_obfs(section)
	if not section or section == "" or section == "nil" then
		return false
	end
	local plugin = (uci:get("shadowsocksr", section, "plugin") or ""):lower()
	if plugin:match("obfs") then
		return true
	end
	local plugin_opts = (uci:get("shadowsocksr", section, "plugin_opts") or ""):lower()
	if plugin_opts:match("obfs") then
		return true
	end
	local obfs = (uci:get("shadowsocksr", section, "obfs") or ""):lower()
	return obfs ~= ""
end

local function set_list(config, section, option, values)
	uci:delete(config, section, option)
	for _, value in ipairs(values or {}) do
		if value and value ~= "" then
			uci:add_list(config, section, option, value)
		end
	end
end

local function resolve_ipv4_stable(domain)
	if not domain or domain == "" then
		return ""
	end
	local resolvers = { "119.29.29.29", "223.5.5.5", "114.114.114.114", "127.0.0.1" }
	for _, resolver in ipairs(resolvers) do
		local output = exec("nslookup " .. shell_quote(domain) .. " " .. resolver)
		local answer = false
		for line in output:gmatch("[^\r\n]+") do
			if line:match("^Name:") or line:match("^[Nn]on%-authoritative answer:") then
				answer = true
			elseif answer then
				local value = line:match("Address[^:]*:%s*([0-9%.]+)")
				if value and value ~= "127.0.0.1" then
					return value
				end
			end
		end
	end
	local fallback = exec("resolveip -4 -t 3 " .. shell_quote(domain) .. " | awk 'NR==1{print}'")
	if fallback ~= "" then
		return fallback
	end
	return exec("curl -fsSL " .. shell_quote("http://119.29.29.29/d?dn=" .. domain) .. " | awk -F ';' '{print $1}'")
end

local function refresh_server_ip_cache(section)
	section = normalize_server_section(section)
	if not section or section == "" or section == "nil" then
		return ""
	end
	local server = trim(uci:get("shadowsocksr", section, "server"))
	if server == "" then
		return ""
	end
	if server:match("^%d+%.%d+%.%d+%.%d+$") then
		uci:set("shadowsocksr", section, "ip", server)
		return server
	end
	local ip = resolve_ipv4_stable(server)
	if ip ~= "" then
		uci:set("shadowsocksr", section, "ip", ip)
	end
	return ip
end

local function refresh_all_server_ip_cache()
	local changed = false
	uci:foreach("shadowsocksr", "servers", function(s)
		local ip = refresh_server_ip_cache(s[".name"])
		if ip ~= "" then
			changed = true
		end
	end)
	if changed then
		uci:commit("shadowsocksr")
	end
end

local function ensure_dnsmasq_nft_compat()
	if call("command -v nft >/dev/null 2>&1") ~= 0 then
		return
	end
	local needs_gfwset = exec("grep -Rqs '#inet#ss_spec#gfwlist' /tmp/dnsmasq.d /tmp/etc 2>/dev/null && echo 1 || true") == "1"
	if needs_gfwset and call("nft list set inet ss_spec gfwlist >/dev/null 2>&1") ~= 0 then
		call("nft add set inet ss_spec gfwlist '{ type ipv4_addr; flags interval; auto-merge; }' >/dev/null 2>&1")
	end
end

local function ensure_stable_config()
	local global = uci:get_first("shadowsocksr", "global")
	local access = uci:get_first("shadowsocksr", "access_control")
	local dnsmasq = uci:get_first("dhcp", "dnsmasq")
	if global then
		local active = uci:get("shadowsocksr", global, "global_server")
		local normalized = normalize_server_section(active)
		if normalized ~= tostring(active or "") and normalized ~= "" then
			uci:set("shadowsocksr", global, "global_server", normalized)
		end
		local threads = uci:get("shadowsocksr", global, "threads")
		if not threads or threads == "" then
			uci:set("shadowsocksr", global, "threads", "0")
		end
		if not uci:get("shadowsocksr", global, "ipv6_mode") or uci:get("shadowsocksr", global, "ipv6_mode") == "" then
			uci:set("shadowsocksr", global, "ipv6_mode", "off")
		end
		uci:set("shadowsocksr", global, "run_mode", uci:get("shadowsocksr", global, "run_mode") or "router")
		uci:set("shadowsocksr", global, "dports", "1")
		if not uci:get("shadowsocksr", global, "enable_switch") or uci:get("shadowsocksr", global, "enable_switch") == "" then
			uci:set("shadowsocksr", global, "enable_switch", "0")
		end
		if not uci:get("shadowsocksr", global, "monitor_enable") or uci:get("shadowsocksr", global, "monitor_enable") == "" then
			uci:set("shadowsocksr", global, "monitor_enable", "1")
		end
		if not uci:get("shadowsocksr", global, "switch_time") or uci:get("shadowsocksr", global, "switch_time") == "" then
			uci:set("shadowsocksr", global, "switch_time", "30")
		end
		if not uci:get("shadowsocksr", global, "switch_timeout") or uci:get("shadowsocksr", global, "switch_timeout") == "" then
			uci:set("shadowsocksr", global, "switch_timeout", "3")
		end
		if not uci:get("shadowsocksr", global, "switch_try_count") or uci:get("shadowsocksr", global, "switch_try_count") == "" then
			uci:set("shadowsocksr", global, "switch_try_count", "0")
		end
		if not uci:get("shadowsocksr", global, "switch_window_seconds") or uci:get("shadowsocksr", global, "switch_window_seconds") == "" then
			uci:set("shadowsocksr", global, "switch_window_seconds", "300")
		end
		if not uci:get("shadowsocksr", global, "switch_window_failures") or uci:get("shadowsocksr", global, "switch_window_failures") == "" then
			uci:set("shadowsocksr", global, "switch_window_failures", "10")
		end
		if not uci:get("shadowsocksr", global, "switch_cooldown") or uci:get("shadowsocksr", global, "switch_cooldown") == "" then
			uci:set("shadowsocksr", global, "switch_cooldown", "300")
		end
		if not uci:get("shadowsocksr", global, "switch_probe_host") or uci:get("shadowsocksr", global, "switch_probe_host") == "" then
			uci:set("shadowsocksr", global, "switch_probe_host", "www.google.com")
		end
		if not uci:get("shadowsocksr", global, "switch_probe_port") or uci:get("shadowsocksr", global, "switch_probe_port") == "" then
			uci:set("shadowsocksr", global, "switch_probe_port", "80")
		end
	end
	if access then
		uci:set("shadowsocksr", access, "router_proxy", "1")
	end
	if dnsmasq then
		uci:set("dhcp", dnsmasq, "filter_aaaa", "1")
	end
	uci:commit("shadowsocksr")
	uci:commit("dhcp")
end

local function wait_for_processes(active)
	if not active.section or active.section == "nil" then
		return true, "disabled", "主代理已禁用"
	end
	local helper = dns_helper_name(uci:get_first("shadowsocksr", "global", "pdnsd_enable", "0"))
	local need_obfs = requires_obfs(active.section)
	local deadline = os.time() + 25
	while os.time() <= deadline do
		local has_redir = is_running("ss-redir")
		local has_dns = (not helper or helper == "") or is_running(helper)
		local has_obfs = (not need_obfs) or is_running("obfs-local")
		if has_redir and has_dns and has_obfs then
			return true, "ready", "代理链路已重建"
		end
		os.execute("sleep 1")
	end
	if not is_running("ss-redir") then
		return false, "process", "ss-redir 未成功启动"
	end
	if helper and helper ~= "" and not is_running(helper) then
		return false, "dns", helper .. " 未成功启动"
	end
	if need_obfs and not is_running("obfs-local") then
		return false, "plugin", "obfs-local 未成功启动"
	end
	return false, "process", "代理进程未完全就绪"
end

local function probe_active_node(active)
	local result = {
		target = active.server or "",
		socket = false,
		ping = nil
	}
	if not active or not active.server or active.server == "" or not active.port or active.port == "" then
		return result
	end
	local target = resolve_ipv4(active.server)
	if target ~= "" then
		result.target = target
	end
	local bypass_state = add_probe_bypass(target)
	local tcp_output = exec("tcping -q -c 1 -i 1 -t 2 -p " .. tostring(active.port) .. " " .. shell_quote(result.target))
	result.socket = tcp_output:match("response from") ~= nil
	local ping_output = exec("ping -c 1 -W 1 " .. shell_quote(result.target))
	result.ping = parse_latency_ms(ping_output)
	remove_probe_bypass(bypass_state)
	return result
end

local function wait_for_probe_ready(active, attempts, delay_seconds)
	attempts = tonumber(attempts) or 1
	delay_seconds = tonumber(delay_seconds) or 0
	local probe = { target = active.server or "", socket = false, ping = nil }
	for attempt = 1, attempts do
		probe = probe_active_node(active)
		if probe.socket then
			return probe
		end
		if attempt < attempts and delay_seconds > 0 then
			call("sleep " .. tostring(delay_seconds))
		end
	end
	return probe
end

local function hard_cleanup(reason)
	write_status({
		ok = false,
		phase = "cleanup",
		message = "正在彻底清理残留进程和状态文件",
		reason = reason
	})
	call("/etc/init.d/shadowsocksr stop >/dev/null 2>&1 || true")
	call("killall -q -9 ss-redir sslocal obfs-local dns2tcp dns2socks dns2socks-rust mosdns dnsproxy chinadns-ng ssr-switch microsocks xray >/dev/null 2>&1 || true")
	call("rm -f /tmp/ssrplus-auto-switch.state >/dev/null 2>&1 || true")
	call("rm -f /var/lock/ssr-switch.lock >/dev/null 2>&1 || true")
	call("rm -f /var/run/ssr-rules-daemon.pid >/dev/null 2>&1 || true")
	call("rm -f /tmp/ssr-rules-daemon.pid >/dev/null 2>&1 || true")
	call("sleep 1")
end

local function perform_restart(active, reason, opts)
	opts = opts or {}
	local service_action = opts.service_action or "restart"
	local kill_before = opts.kill_before
	if kill_before == nil then
		kill_before = true
	end
	write_status({
		ok = false,
		phase = "restart",
		message = "正在重启 SSR 主链路",
		reason = reason,
		active = active.alias,
		server = active.server,
		port = active.port
	})

	if kill_before then
		call("killall -q -9 ss-redir sslocal obfs-local dns2tcp dns2socks dns2socks-rust mosdns dnsproxy chinadns-ng ssr-switch >/dev/null 2>&1 || true")
		call("sleep 1")
	end
	local ret = call("/etc/init.d/shadowsocksr " .. service_action .. " >" .. LOG_FILE .. " 2>&1")
	ensure_dnsmasq_nft_compat()
	call("killall -HUP dnsmasq >/dev/null 2>&1 || /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true")
	call("conntrack -F >/dev/null 2>&1 || true")

	local ok, phase, message = wait_for_processes(active)
	local probe = probe_active_node(active)
	return ret, ok, phase, message, probe
end

local function run_ipv6_main(reason)
	local active = get_active_node()
	local ipv6_before = get_ipv6_state()
	write_status({
		ok = false,
		phase = "prepare",
		message = "正在同步 IPv6 设置",
		reason = reason,
		active = active.alias,
		server = active.server,
		port = active.port,
		ipv6_mode = ipv6_before.mode,
		ipv6_status = ipv6_before.status
	})
	local ipv6 = apply_ipv6_mode_config(ipv6_before.mode)
	call("/etc/init.d/network reload >/dev/null 2>&1 || true")
	call("/etc/init.d/odhcpd restart >/dev/null 2>&1 || true")
	call("killall -HUP dnsmasq >/dev/null 2>&1 || /etc/init.d/dnsmasq restart >/dev/null 2>&1 || true")
	call("sleep 2")
	ipv6 = get_ipv6_state(ipv6.mode)
	local message
	if ipv6.mode == "auto" then
		message = ipv6.desired_enabled
			and "IPv6 自动模式已生效，检测到可用 LAN/WAN6 时会保持系统 IPv6 开启，AAAA 过滤保持开启"
			or "IPv6 自动模式已生效，但当前 LAN/WAN6 还不满足启用条件，系统 IPv6 保持关闭，AAAA 过滤保持开启"
	elseif ipv6.enabled then
		message = "系统 IPv6 已开启。注意：当前 SSR 仍以 IPv4 透明代理为主，AAAA 过滤保持开启以避免 IPv6 直连泄露"
	else
		message = "系统 IPv6 已关闭，当前网络仅使用 IPv4 透明代理"
	end
	local data = write_status({
		ok = true,
		phase = "done",
		message = message,
		reason = reason,
		active = active.alias,
		server = active.server,
		port = active.port,
		ipv6_mode = ipv6.mode,
		ipv6_enabled = ipv6.enabled,
		ipv6_desired_enabled = ipv6.desired_enabled,
		ipv6_filter_aaaa = ipv6.filter_aaaa,
		ipv6_status = ipv6.status
	})
	io.write(jsonc.stringify(data) or "{}")
end

local function run_main()
	local reason = arg[1] or "apply"

	if reason == "ipv6_enable" or reason == "ipv6_disable" or reason == "ipv6_auto" then
		run_ipv6_main(reason)
		return
	end

	write_status({
		ok = false,
		phase = "prepare",
		message = "正在准备同步生效链路",
		reason = reason
	})

	ensure_stable_config()
	refresh_all_server_ip_cache()

	call("killall -q -9 ssr-switch >/dev/null 2>&1 || true")
	call("rm -f /var/lock/ssr-switch.lock >/dev/null 2>&1 || true")

	local hard_rebuild = reason == "hard_rebuild"
	if hard_rebuild then
		hard_cleanup(reason)
	end

	local active = get_active_node()
	if active.section == "nil" then
		call("/etc/init.d/shadowsocksr stop >/dev/null 2>&1 || true")
		call("killall -q -9 ss-redir sslocal obfs-local dns2tcp dns2socks dns2socks-rust mosdns dnsproxy chinadns-ng >/dev/null 2>&1 || true")
		local data = write_status({
			ok = true,
			phase = "disabled",
			message = "主代理已关闭，旧代理进程已停止",
			reason = reason,
			active = active.alias,
			server = active.server,
			port = active.port,
			ip = ""
		})
		io.write(jsonc.stringify(data) or "{}")
		return
	end

	write_status({
		ok = false,
		phase = "restart",
		message = "正在重启 SSR 主链路",
		reason = reason,
		active = active.alias,
		server = active.server,
		port = active.port
	})

	local restart_opts = nil
	if hard_rebuild then
		restart_opts = { service_action = "start", kill_before = false }
	end
	local ret, ok, phase, message, probe = perform_restart(active, reason, restart_opts)
	local data = {
		ok = false,
		phase = phase,
		message = message,
		reason = reason,
		active = active.alias,
		server = active.server,
		port = active.port,
		log = LOG_FILE
	}

	if ret ~= 0 and not ok then
		data.phase = "restart"
		data.message = "shadowsocksr 重启失败"
		write_status(data)
		io.write(jsonc.stringify(data) or "{}")
		return
	end

	if ok and not probe.socket then
		write_status({
			ok = false,
			phase = "prepare",
			message = "代理进程已启动，正在等待当前节点端口探测稳定",
			reason = reason,
			active = active.alias,
			server = active.server,
			port = active.port
		})
		probe = wait_for_probe_ready(active, 4, 2)
	end

	data.probe_socket = probe.socket
	data.probe_ping = probe.ping
	data.probe_target = probe.target

	local should_retry = (not hard_rebuild)
		and (reason == "apply" or reason == "rebuild" or reason == "restart")
		and ((ret ~= 0 and not ok) or not ok)
	if should_retry then
		write_status({
			ok = false,
			phase = "retry",
			message = "首次切换未稳定，正在彻底清理后重试",
			reason = reason,
			active = active.alias,
			server = active.server,
			port = active.port
		})
		hard_cleanup("hard_rebuild")
		ret, ok, phase, message, probe = perform_restart(active, "hard_rebuild", { service_action = "start", kill_before = false })
		data.phase = phase
		data.message = message
		data.reason = "hard_rebuild"
		data.probe_socket = probe.socket
		data.probe_ping = probe.ping
		data.probe_target = probe.target
	end

	if ok and not probe.socket then
		data.ok = false
		data.phase = "probe"
		data.message = "当前节点端口探测失败，代理进程已启动但未能连通节点服务器"
		write_status(data)
		io.write(jsonc.stringify(data) or "{}")
		return
	end

	local direct_ip = get_direct_public_ip()
	local public_ip = ""
	for attempt = 1, 4 do
		public_ip = get_public_ip(1, 0)
		if public_ip ~= "" and (direct_ip == "" or public_ip ~= direct_ip) then
			break
		end
		if attempt < 4 then
			call("sleep 2")
		end
	end
	data.ip = public_ip
	data.direct_ip = direct_ip
	if ok and public_ip ~= "" and (direct_ip == "" or public_ip ~= direct_ip) then
		data.ok = true
		data.phase = "done"
		data.message = "代理链路已完成重建，当前节点探测正常，已拿到路由器自检出口 IP，请以客户端访问结果为准"
	elseif ok and public_ip ~= "" and direct_ip ~= "" and public_ip == direct_ip then
		data.ok = true
		data.phase = "verify_warn"
		data.message = "主代理进程已运行，但当前拿到的是直连公网 IP，代理出口仍在切换，请以客户端访问结果为准"
	elseif ok then
		data.ok = true
		data.phase = "verify_warn"
		data.message = "当前节点探测正常，但路由器自检未拿到出口 IP，请以客户端访问结果为准"
	else
		data.ok = false
		data.phase = phase
		data.message = message
	end

	write_status(data)
	io.write(jsonc.stringify(data) or "{}")
end

local function main()
	local locked = acquire_lock()
	if not locked then
		local current = read_status() or {}
		current.ok = false
		current.phase = "busy"
		current.message = "已有后台生效任务正在运行，请稍候"
		current.time = os.date("%Y-%m-%d %H:%M:%S")
		write_status(current)
		io.write(jsonc.stringify(current) or "{}")
		return
	end

	local ok, result = xpcall(run_main, debug.traceback)
	release_lock()
	if not ok then
		local data = write_status({
			ok = false,
			phase = "error",
			message = "后台生效任务异常退出",
			error = tostring(result or "")
		})
		io.write(jsonc.stringify(data) or "{}")
	end
end

main()
