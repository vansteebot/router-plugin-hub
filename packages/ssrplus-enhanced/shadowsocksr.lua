-- Copyright (C) 2017 yushi studio <ywb94@qq.com>
-- Licensed to the public under the GNU General Public License v3.
module("luci.controller.shadowsocksr", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/shadowsocksr") then
		call("act_reset")
	end
	local page
	page = entry({"admin", "services", "shadowsocksr"}, alias("admin", "services", "shadowsocksr", "client"), _("ShadowSocksR Plus+"), 10)
	page.dependent = true
	
	entry({"admin", "services", "shadowsocksr", "client"}, cbi("shadowsocksr/client"), _("SSR Client"), 10).leaf = true
	entry({"admin", "services", "shadowsocksr", "servers"}, arcombine(cbi("shadowsocksr/servers"), cbi("shadowsocksr/client-config")), _("Servers Nodes"), 20).leaf = true
	entry({"admin", "services", "shadowsocksr", "control"}, cbi("shadowsocksr/control"), _("Access Control"), 30).leaf = true
	entry({"admin", "services", "shadowsocksr", "advanced"}, cbi("shadowsocksr/advanced"), _("Advanced Settings"), 50).leaf = true
	entry({"admin", "services", "shadowsocksr", "server"}, arcombine(cbi("shadowsocksr/server"), cbi("shadowsocksr/server-config")), _("SSR Server"), 60).leaf = true
	entry({"admin", "services", "shadowsocksr", "status"}, form("shadowsocksr/status"), _("Status"), 70).leaf = true
	entry({"admin", "services", "shadowsocksr", "check"}, call("check_status"))
	entry({"admin", "services", "shadowsocksr", "refresh"}, call("refresh_data"))
	entry({"admin", "services", "shadowsocksr", "subscribe"}, call("subscribe"))
	entry({"admin", "services", "shadowsocksr", "checkport"}, call("check_port"))
	entry({"admin", "services", "shadowsocksr", "log"}, form("shadowsocksr/log"), _("Log"), 80).leaf = true
	entry({"admin", "services", "shadowsocksr", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "services", "shadowsocksr", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "services", "shadowsocksr", "run"}, call("act_status"))
	entry({"admin", "services", "shadowsocksr", "status_info"}, call("act_status_info")).leaf = true
	entry({"admin", "services", "shadowsocksr", "ping"}, call("act_ping"))
	entry({"admin", "services", "shadowsocksr", "reset"}, call("act_reset"))
	entry({"admin", "services", "shadowsocksr", "restart"}, call("act_restart"))
	entry({"admin", "services", "shadowsocksr", "apply_sync"}, call("act_apply_sync")).leaf = true
	entry({"admin", "services", "shadowsocksr", "apply_split_mode"}, call("act_apply_split_mode")).leaf = true
	entry({"admin", "services", "shadowsocksr", "flush_fast"}, call("act_quick_flush")).leaf = true
	entry({"admin", "services", "shadowsocksr", "flush"}, call("act_flush")).leaf = true
	entry({"admin", "services", "shadowsocksr", "flush_hard"}, call("act_flush_hard")).leaf = true
	entry({"admin", "services", "shadowsocksr", "toggle_ipv6"}, call("act_toggle_ipv6")).leaf = true
	entry({"admin", "services", "shadowsocksr", "import_ss"}, call("act_import_ss")).leaf = true
	entry({"admin", "services", "shadowsocksr", "export_full"}, call("export_full_backup")).leaf = true
	entry({"admin", "services", "shadowsocksr", "export_installer"}, call("export_installer")).leaf = true
	entry({"admin", "services", "shadowsocksr", "export_windows_recover"}, call("export_windows_recover")).leaf = true
	entry({"admin", "services", "shadowsocksr", "delete"}, call("act_delete"))
	entry({"admin", "services", "shadowsocksr", "delete_selected"}, call("act_delete_selected")).leaf = true
	entry({'admin', 'services', "shadowsocksr", 'ip'}, call('check_ip')) -- 获取ip情况
		--[[Backup]]
	entry({"admin", "services", "shadowsocksr", "backup"}, call("create_backup")).leaf = true
	
end

local function shell_quote(value)
	value = tostring(value or "")
	value = value:gsub("'", [['"'"']])
	return "'" .. value .. "'"
end

local function write_json(tbl)
	luci.http.prepare_content("application/json")
	luci.http.write_json(tbl)
end

local STATUS_FILE = "/tmp/ssrplus-action-status.json"
local SYNC_APPLY_SCRIPT = "/usr/share/shadowsocksr/sync-apply.lua"
local SYNC_APPLY_LOCK_FILE = "/var/lock/ssrplus-sync-apply.lock"
local WINDOWS_RECOVER_FILE = "/usr/share/shadowsocksr/windows-clash-recover.ps1"
local AUTO_SWITCH_STATE_FILE = "/tmp/ssrplus-auto-switch.state"

local function trim(value)
	value = tostring(value or "")
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function run_command(cmd)
	return trim(luci.sys.exec(cmd .. " 2>/dev/null"))
end

local function read_status_file()
	local raw = nixio.fs.readfile(STATUS_FILE)
	if not raw or raw == "" then
		return nil
	end
	return luci.jsonc.parse(raw)
end

local function write_status_file(data)
	if not data.time then
		data.time = os.date("%Y-%m-%d %H:%M:%S")
	end
	nixio.fs.writefile(STATUS_FILE, luci.jsonc.stringify(data) or "{}")
	return data
end

local function read_key_value_file(path)
	local result = {}
	local raw = nixio.fs.readfile(path)
	if not raw or raw == "" then
		return result
	end
	for line in raw:gmatch("[^\r\n]+") do
		local key, value = line:match("^([A-Z0-9_]+)=(.*)$")
		if key then
			result[key] = value
		end
	end
	return result
end

local function is_process_running(pattern)
	local count = run_command("busybox ps -w | grep " .. shell_quote(pattern) .. " | grep -v grep | wc -l")
	return tonumber(count) and tonumber(count) > 0 or false
end

local function sync_apply_is_running()
	local pid = trim(run_command("cat " .. shell_quote(SYNC_APPLY_LOCK_FILE)))
	if pid == "" then
		return false
	end
	return luci.sys.call("kill -0 " .. pid .. " >/dev/null 2>&1") == 0
end

local function get_list(cursor, config, section, option)
	local values = cursor.get_list and cursor:get_list(config, section, option) or nil
	if type(values) == "table" then
		return values
	end
	values = cursor:get(config, section, option)
	if type(values) == "table" then
		return values
	end
	if values and values ~= "" then
		return { values }
	end
	return {}
end

local function set_list(cursor, config, section, option, values)
	cursor:delete(config, section, option)
	local clean = {}
	for _, value in ipairs(values or {}) do
		if value and value ~= "" then
			table.insert(clean, value)
		end
	end
	if #clean > 0 then
		if cursor.set_list then
			cursor:set_list(config, section, option, clean)
		else
			cursor:set(config, section, option, clean)
		end
	end
end

local function append_unique(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return list
		end
	end
	table.insert(list, value)
	return list
end

local function remove_value(list, value)
	local result = {}
	for _, item in ipairs(list or {}) do
		if item ~= value then
			table.insert(result, item)
		end
	end
	return result
end

local function normalize_server_section(cursor, section)
	section = tostring(section or "")
	local index = section:match("^@servers%[(%d+)%]$")
	if not index then
		return section
	end
	index = tonumber(index)
	local current = 0
	local resolved = section
	cursor:foreach("shadowsocksr", "servers", function(s)
		if current == index then
			resolved = s[".name"] or section
		end
		current = current + 1
	end)
	return resolved
end

local function apply_stability_preset(cursor)
	local global = cursor:get_first("shadowsocksr", "global")
	local access = cursor:get_first("shadowsocksr", "access_control")
	local dnsmasq = cursor:get_first("dhcp", "dnsmasq")
	if global then
		local active = cursor:get("shadowsocksr", global, "global_server")
		local normalized = normalize_server_section(cursor, active)
		if normalized ~= tostring(active or "") and normalized ~= "" then
			cursor:set("shadowsocksr", global, "global_server", normalized)
		end
		local threads = cursor:get("shadowsocksr", global, "threads")
		if not threads or threads == "" then
			cursor:set("shadowsocksr", global, "threads", "0")
		end
		if not cursor:get("shadowsocksr", global, "ipv6_mode") or cursor:get("shadowsocksr", global, "ipv6_mode") == "" then
			cursor:set("shadowsocksr", global, "ipv6_mode", "off")
		end
		cursor:set("shadowsocksr", global, "dports", "1")
		if not cursor:get("shadowsocksr", global, "enable_switch") or cursor:get("shadowsocksr", global, "enable_switch") == "" then
			cursor:set("shadowsocksr", global, "enable_switch", "0")
		end
		if not cursor:get("shadowsocksr", global, "monitor_enable") or cursor:get("shadowsocksr", global, "monitor_enable") == "" then
			cursor:set("shadowsocksr", global, "monitor_enable", "1")
		end
		if not cursor:get("shadowsocksr", global, "switch_time") or cursor:get("shadowsocksr", global, "switch_time") == "" then
			cursor:set("shadowsocksr", global, "switch_time", "60")
		end
		if not cursor:get("shadowsocksr", global, "switch_timeout") or cursor:get("shadowsocksr", global, "switch_timeout") == "" then
			cursor:set("shadowsocksr", global, "switch_timeout", "3")
		end
		if not cursor:get("shadowsocksr", global, "switch_try_count") or cursor:get("shadowsocksr", global, "switch_try_count") == "" then
			cursor:set("shadowsocksr", global, "switch_try_count", "4")
		end
		if not cursor:get("shadowsocksr", global, "switch_probe_host") or cursor:get("shadowsocksr", global, "switch_probe_host") == "" then
			cursor:set("shadowsocksr", global, "switch_probe_host", "www.google.com")
		end
		if not cursor:get("shadowsocksr", global, "switch_probe_port") or cursor:get("shadowsocksr", global, "switch_probe_port") == "" then
			cursor:set("shadowsocksr", global, "switch_probe_port", "80")
		end
	end
	if access then
		cursor:set("shadowsocksr", access, "router_proxy", "1")
	end
	if dnsmasq then
		cursor:set("dhcp", dnsmasq, "filter_aaaa", "1")
	end
	cursor:commit("shadowsocksr")
	cursor:commit("dhcp")
	luci.sys.call("killall -q -9 ssr-switch >/dev/null 2>&1 || true")
	luci.sys.call("rm -f /var/lock/ssr-switch.lock >/dev/null 2>&1 || true")
end

local function get_active_node()
	local uci = require "luci.model.uci".cursor()
	local active = normalize_server_section(uci, uci:get_first("shadowsocksr", "global", "global_server", "nil"))
	local alias, server, port = "停用", "", ""
	if active and active ~= "" and active ~= "nil" then
		alias = uci:get("shadowsocksr", active, "alias") or alias
		server = uci:get("shadowsocksr", active, "server") or server
		port = uci:get("shadowsocksr", active, "server_port") or port
	end
	uci:foreach("shadowsocksr", "servers", function(s)
		if alias == "停用" and s[".name"] == active then
			alias = s.alias or s.server or active
			server = s.server or ""
			port = s.server_port or ""
		end
	end)
	return {
		section = active,
		alias = alias,
		server = server,
		port = port
	}
end

local function parse_ifstatus_json(name)
	local raw = run_command("ifstatus " .. shell_quote(name))
	if raw == "" then
		return nil
	end
	local parsed = luci.jsonc.parse(raw)
	if type(parsed) == "table" then
		return parsed
	end
	return nil
end

local function list_count(value)
	if type(value) ~= "table" then
		return 0
	end
	return #value
end

local function get_ipv6_state(cursor, mode_override)
	cursor = cursor or require "luci.model.uci".cursor()
	local global = cursor:get_first("shadowsocksr", "global")
	local mode = trim(mode_override or (global and cursor:get("shadowsocksr", global, "ipv6_mode") or "off"))
	if mode == "" then
		mode = "off"
	end

	local dnsmasq = cursor:get_first("dhcp", "dnsmasq")
	local filter_aaaa = dnsmasq and cursor:get("dhcp", dnsmasq, "filter_aaaa") or "0"
	local wan6_exists = cursor:get("network", "wan6") ~= nil
	local wan6_disabled = cursor:get("network", "wan6", "disabled") or "1"
	local wan6_proto = trim(cursor:get("network", "wan6", "proto") or "")
	local lan_ip6assign = trim(cursor:get("network", "lan", "ip6assign") or "")
	local lan_dhcpv6 = cursor:get("dhcp", "lan", "dhcpv6") or "disabled"
	local lan_ra = cursor:get("dhcp", "lan", "ra") or "disabled"
	local lan_supported = lan_ip6assign ~= "" and lan_ip6assign ~= "0"
	local enabled = wan6_disabled ~= "1" and lan_dhcpv6 ~= "disabled" and lan_ra ~= "disabled"

	local wan6_status = parse_ifstatus_json("wan6") or {}
	local wan6_online = wan6_status.up == true
		or list_count(wan6_status["ipv6-address"]) > 0
		or list_count(wan6_status["ipv6-prefix-assignment"]) > 0
		or list_count(wan6_status["ipv6-prefix"]) > 0
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
		summary = table.concat(summary_parts, " / "),
		lan_supported = lan_supported,
		auto_supported = auto_supported,
		wan6_online = wan6_online,
		wan6_exists = wan6_exists,
		wan6_proto = wan6_proto
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
			local ip = run_command("curl -4 -m 8 -fsSL " .. shell_quote(url))
			if ip ~= "" then
				return ip
			end
		end
		if attempt < attempts and delay_seconds > 0 then
			luci.sys.call("sleep " .. tostring(delay_seconds))
		end
	end
	return ""
end

local function extract_public_ipv4(text)
	local ip = trim(text):match("(%d+%.%d+%.%d+%.%d+)")
	return ip or ""
end

local function get_direct_public_ip()
	local endpoints = {
		"https://myip.ipip.net",
		"https://ddns.oray.com/checkip",
		"https://ip.3322.net"
	}
	for _, url in ipairs(endpoints) do
		local raw = run_command("curl --noproxy '*' -4 -m 8 -fsSL " .. shell_quote(url))
		local ip = extract_public_ipv4(raw)
		if ip ~= "" then
			return ip
		end
	end
	return ""
end

local function now_string()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function count_auto_switch_candidates(cursor)
	local count = 0
	cursor:foreach("shadowsocksr", "servers", function(s)
		if tostring(s.switch_enable or "0") == "1" then
			count = count + 1
		end
	end)
	return count
end

local function build_auto_switch_state(cursor)
	local global = cursor:get_first("shadowsocksr", "global")
	local state = read_key_value_file(AUTO_SWITCH_STATE_FILE)
	local enabled = global and cursor:get("shadowsocksr", global, "enable_switch") == "1" or false
	local interval = global and (cursor:get("shadowsocksr", global, "switch_time") or "30") or "30"
	local threshold = global and (cursor:get("shadowsocksr", global, "switch_try_count") or "0") or "0"
	local window_seconds = global and (cursor:get("shadowsocksr", global, "switch_window_seconds") or "300") or "300"
	local window_threshold = global and (cursor:get("shadowsocksr", global, "switch_window_failures") or "10") or "10"
	local cooldown = global and (cursor:get("shadowsocksr", global, "switch_cooldown") or "300") or "300"
	local host = global and (cursor:get("shadowsocksr", global, "switch_probe_host") or "www.google.com") or "www.google.com"
	local port = global and (cursor:get("shadowsocksr", global, "switch_probe_port") or "80") or "80"
	local running = enabled and is_process_running("ssr-switch") or false
	local fail_count = tonumber(state.FAIL_COUNT or "0") or 0
	local window_fail_count = tonumber(state.WINDOW_FAIL_COUNT or "0") or 0
	local last_switch_at = tonumber(state.LAST_SWITCH_AT or "0") or 0
	local last_switch_text = ""
	if last_switch_at > 0 then
		last_switch_text = os.date("%Y-%m-%d %H:%M:%S", last_switch_at)
	end
	return {
		auto_switch_enabled = enabled,
		auto_switch_running = running,
		auto_switch_fail_count = fail_count,
		auto_switch_threshold = tonumber(threshold) or 0,
		auto_switch_window_fail_count = window_fail_count,
		auto_switch_window_seconds = tonumber(window_seconds) or 300,
		auto_switch_window_threshold = tonumber(window_threshold) or 10,
		auto_switch_cooldown = tonumber(cooldown) or 300,
		auto_switch_interval = tonumber(interval) or 30,
		auto_switch_host = host,
		auto_switch_port = tonumber(port) or 80,
		auto_switch_candidates = count_auto_switch_candidates(cursor),
		auto_switch_last_action = state.LAST_ACTION or "",
		auto_switch_last_probe = state.LAST_PROBE or "",
		auto_switch_last_switch = last_switch_text,
		auto_switch_last_target = state.LAST_SWITCH_TARGET or "",
		auto_switch_last_reason = state.LAST_SWITCH_REASON or ""
	}
end

local function run_sync_apply(reason)
	local cmd = string.format(
		"/usr/bin/lua %s %s",
		shell_quote(SYNC_APPLY_SCRIPT),
		shell_quote(reason or "apply")
	)
	luci.sys.call(cmd .. " >/dev/null 2>&1")
	return read_status_file() or {
		ok = false,
		phase = "unknown",
		message = "同步生效脚本没有返回状态",
		time = now_string()
	}
end

local function build_sync_apply_command(reason)
	return string.format(
		"/usr/bin/lua %s %s",
		shell_quote(SYNC_APPLY_SCRIPT),
		shell_quote(reason or "apply")
	)
end

local build_status_info

local function queue_sync_apply(reason, message)
	if sync_apply_is_running() then
		local current = build_status_info()
		current.ok = false
		current.queued = false
		current.phase = "busy"
		current.message = "已有后台生效任务正在运行，请等待当前任务完成"
		current.reason = reason or current.reason or "apply"
		current.time = now_string()
		write_status_file(current)
		return current
	end
	local queued = build_status_info()
	queued.ok = true
	queued.queued = true
	queued.phase = "queued"
	queued.message = message or "配置已保存，后台正在生效"
	queued.reason = reason or "apply"
	queued.time = now_string()
	write_status_file(queued)
	luci.sys.call("( " .. build_sync_apply_command(reason) .. " >/tmp/ssrplus-sync-apply-bg.log 2>&1 ) &")
	return queued
end

build_status_info = function()
	local cursor = require "luci.model.uci".cursor()
	local active = get_active_node()
	local run_mode = cursor:get_first("shadowsocksr", "global", "run_mode", "router")
	local info = read_status_file() or {}
	local auto_switch = build_auto_switch_state(cursor)
	local ipv6 = get_ipv6_state(cursor)
	local recorded_section = normalize_server_section(cursor, info.active_section)
	if (recorded_section ~= "" and recorded_section ~= active.section)
		or (info.disabled and active.section ~= "nil")
	then
		info = {}
	end
	local ss_redir_running = is_process_running("ss-redir")
	info.disabled = active.section == "nil"
	info.stale_process = info.disabled and ss_redir_running or false
	info.running = (not info.disabled) and ss_redir_running or false
	info.active = active.alias
	info.active_section = active.section
	info.server = active.server
	info.port = active.port
	info.time = info.time or now_string()
	info.direct_ip = trim(info.direct_ip or "")
	if info.disabled then
		info.phase = "disabled"
		info.ip = ""
		info.ok = not info.stale_process
		info.message = info.stale_process
			and "主服务器已停用，但检测到旧代理进程残留，正在等待后台清理"
			or "主代理已关闭，无需重建"
	elseif not info.running then
		info.ok = false
		info.phase = "process"
		info.ip = ""
		info.message = "主代理进程未运行，请重新生效网络"
	elseif not info.message or info.message == "" then
		info.message = info.running and "代理运行中" or "代理未运行"
	end
	if info.direct_ip == "" then
		info.direct_ip = get_direct_public_ip()
	end
	if sync_apply_is_running() and info.phase ~= "busy" then
		info.phase = info.phase == "queued" and "queued" or "busy"
		info.message = "后台生效任务正在运行，按钮已锁定，请等待完成"
	end
	if (not info.disabled) and info.running and ((not info.ip or info.ip == "") or info.phase == "verify_warn") then
		local current_ip = get_public_ip(1, 0)
		if current_ip ~= "" then
			info.ip = current_ip
			if run_mode == "gfw" and info.direct_ip ~= "" and current_ip == info.direct_ip then
				info.ok = true
				info.phase = "done"
				info.message = "GFW 列表模式下路由器自检出口可能显示为直连公网 IP，请以客户端实际访问结果为准"
			elseif info.direct_ip ~= "" and current_ip == info.direct_ip then
				info.ok = true
				info.phase = "verify_warn"
				info.message = "主代理进程已运行，但当前拿到的是直连公网 IP，代理出口仍在切换，请以客户端访问结果为准"
			else
				info.ok = true
				info.phase = "done"
				info.message = "代理链路已完成重建，已拿到路由器自检出口 IP，请以客户端访问结果为准"
			end
			write_status_file(info)
		end
	end
	for key, value in pairs(auto_switch) do
		info[key] = value
	end
	info.ipv6_enabled = ipv6.enabled
	info.ipv6_mode = ipv6.mode
	info.ipv6_mode_label = ipv6.mode_label
	info.ipv6_desired_enabled = ipv6.desired_enabled
	info.ipv6_filter_aaaa = ipv6.filter_aaaa
	info.ipv6_auto_supported = ipv6.auto_supported
	info.ipv6_lan_supported = ipv6.lan_supported
	info.ipv6_wan6_online = ipv6.wan6_online
	info.ipv6_proxy_supported = false
	info.ipv6_status = ipv6.summary
	return info
end

local function run_enhanced_restart(wait_mode)
	local arg = wait_mode and "" or " --bg"
	local cmd = "/usr/share/shadowsocksr/restart-enhanced.sh" .. arg .. " >/tmp/ssrplus-enhanced-restart.log 2>&1"
	local ret = luci.sys.call(cmd)
	if wait_mode then
		luci.sys.call("sleep 2")
	end
	return ret
end

local function run_fast_restart(wait_mode)
	local arg = wait_mode and "" or " --bg"
	local cmd = "/usr/share/shadowsocksr/restart-fast.sh" .. arg .. " >/tmp/ssrplus-fast-restart.log 2>&1"
	local ret = luci.sys.call(cmd)
	if wait_mode then
		luci.sys.call("sleep 1")
	end
	return ret
end

function check_site(host, port)
    local nixio = require "nixio"
    local socket = nixio.socket("inet", "stream")
    socket:setopt("socket", "rcvtimeo", 2)
    socket:setopt("socket", "sndtimeo", 2)
    local ret = socket:connect(host, port)
    socket:close()
    return ret
end

function get_ip_geo_info()
    local result = luci.sys.exec('curl --retry 3 -m 10 -LfsA "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.183 Safari/537.36" http://ip-api.com/json/')
    local json = require "luci.jsonc"
    local info = json.parse(result)
    
    return {
        flag = string.lower(info.countryCode) or "un",
        country = get_country_name(info.countryCode) or "Unknown",
        ip = info.query,
        isp = info.isp
    }
end

function get_country_name(countryCode)
    local country_names = {
        US = "美国", CN = "中国", JP = "日本", GB = "英国", DE = "德国",
        FR = "法国", BR = "巴西", IT = "意大利", RU = "俄罗斯", CA = "加拿大",
        KR = "韩国", ES = "西班牙", AU = "澳大利亚", MX = "墨西哥", ID = "印度尼西亚",
        NL = "荷兰", TR = "土耳其", CH = "瑞士", SA = "沙特阿拉伯", SE = "瑞典",
        PL = "波兰", BE = "比利时", AR = "阿根廷", NO = "挪威", AT = "奥地利",
        TW = "台湾", ZA = "南非", TH = "泰国", DK = "丹麦", MY = "马来西亚",
        PH = "菲律宾", SG = "新加坡", IE = "爱尔兰", HK = "香港", FI = "芬兰",
        CL = "智利", PT = "葡萄牙", GR = "希腊", IL = "以色列", NZ = "新西兰",
        CZ = "捷克", RO = "罗马尼亚", VN = "越南", UA = "乌克兰", HU = "匈牙利",
        AE = "阿联酋", CO = "哥伦比亚", IN = "印度", EG = "埃及", PE = "秘鲁", TW = "台湾"
    }
    return country_names[countryCode]
end

function check_ip()
    local e = {}
    local port = 80
    local geo_info = get_ip_geo_info(ip)
    e.ip = geo_info.ip
    e.flag = geo_info.flag
    e.country = geo_info.country
    e.isp = geo_info.isp
    e.baidu = check_site('www.baidu.com', port)
    e.taobao = check_site('www.taobao.com', port)
    e.google = check_site('www.google.com', port)
    e.youtube = check_site('www.youtube.com', port)
    luci.http.prepare_content('application/json')
    luci.http.write_json(e)
end

function subscribe()
	luci.sys.call("/usr/bin/lua /usr/share/shadowsocksr/subscribe.lua >>/var/log/ssrplus.log")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ret = 1})
end

local function maybe_queue_ipv6_auto(info)
	if not info or info.ipv6_mode ~= "auto" then
		return info
	end
	if sync_apply_is_running() then
		return info
	end
	if info.ipv6_enabled == info.ipv6_desired_enabled then
		return info
	end
	local message = info.ipv6_desired_enabled
		and "自动模式检测到 LAN/WAN6 支持 IPv6，正在后台同步系统 IPv6，AAAA 过滤保持开启"
		or "自动模式检测到当前 LAN/WAN6 不适合启用 IPv6，正在后台关闭系统 IPv6，AAAA 过滤保持开启"
	return queue_sync_apply("ipv6_auto", message)
end

function act_status()
	write_json(maybe_queue_ipv6_auto(build_status_info()))
end

function act_status_info()
	write_json(maybe_queue_ipv6_auto(build_status_info()))
end

local function resolve_ipv4(domain)
	if not domain or domain == "" then
		return ""
	end
	if domain:match("^%d+%.%d+%.%d+%.%d+$") then
		return domain
	end
	for _, resolver in ipairs({ "119.29.29.29", "223.5.5.5", "127.0.0.1" }) do
		local output = luci.sys.exec("timeout 3 nslookup " .. shell_quote(domain) .. " " .. resolver .. " 2>/dev/null")
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
	local fallback = trim(luci.sys.exec("resolveip -4 -t 2 " .. shell_quote(domain) .. " 2>/dev/null | awk 'NR==1{print}'"))
	if fallback ~= "" then
		return fallback
	end
	fallback = trim(luci.sys.exec("timeout 3 curl -fsSL " .. shell_quote("http://119.29.29.29/d?dn=" .. domain) .. " 2>/dev/null | awk -F ';' '{print $1}'"))
	if fallback ~= "" and fallback:match("^%d+%.%d+%.%d+%.%d+$") then
		return fallback
	end
	fallback = trim(luci.sys.exec("getent ahostsv4 " .. shell_quote(domain) .. " 2>/dev/null | awk 'NR==1{print $1}'"))
	if fallback ~= "" and fallback:match("^%d+%.%d+%.%d+%.%d+$") then
		return fallback
	end
	return ""
end

local function cached_ipv4_for_domain(domain)
	if not domain or domain == "" then
		return ""
	end
	local cursor = require "luci.model.uci".cursor()
	local cached = ""
	cursor:foreach("shadowsocksr", "servers", function(s)
		if s.server == domain and s.ip and s.ip:match("^%d+%.%d+%.%d+%.%d+$") then
			cached = s.ip
		end
	end)
	return cached
end

local function nft_bypass_sets()
	local sets = {}
	if luci.sys.call("nft list set inet ss_spec ss_spec_wan_ac_tcp >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac_tcp")
	end
	if luci.sys.call("nft list set inet ss_spec ss_spec_wan_ac_udp >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac_udp")
	end
	if #sets == 0 and luci.sys.call("nft list set inet ss_spec ss_spec_wan_ac >/dev/null 2>&1") == 0 then
		table.insert(sets, "ss_spec_wan_ac")
	end
	return sets
end

local function add_ping_bypass(target)
	if not target or target == "" or not target:match("^%d+%.%d+%.%d+%.%d+$") then
		return nil
	end
	local use_nft = luci.sys.call("command -v nft >/dev/null 2>&1") == 0
	if use_nft then
		local added = {}
		for _, set_name in ipairs(nft_bypass_sets()) do
			if luci.sys.call("nft add element inet ss_spec " .. set_name .. " { " .. target .. " } >/dev/null 2>&1") == 0 then
				table.insert(added, set_name)
			end
		end
		if #added > 0 then
			return { use_nft = true, target = target, sets = added }
		end
		return nil
	end
	if luci.sys.call("ipset add ss_spec_wan_ac " .. target .. " >/dev/null 2>&1") == 0 then
		return { use_nft = false, target = target }
	end
	return nil
end

local function remove_ping_bypass(state)
	if not state or not state.target or state.target == "" or not state.target:match("^%d+%.%d+%.%d+%.%d+$") then
		return
	end
	if state.use_nft then
		for _, set_name in ipairs(state.sets or {}) do
			luci.sys.call("nft delete element inet ss_spec " .. set_name .. " { " .. state.target .. " } >/dev/null 2>&1")
		end
	else
		luci.sys.call("ipset del ss_spec_wan_ac " .. state.target .. " >/dev/null 2>&1")
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

function act_ping()
	local e = {}
	local domain = trim(luci.http.formvalue("domain"))
	local port = tonumber(luci.http.formvalue("port") or 0)
	local transport = trim(luci.http.formvalue("transport"))
	local wsPath = luci.http.formvalue("wsPath") or ""
	local tls = luci.http.formvalue("tls")
	e.index = luci.http.formvalue("index")
	e.socket = false

	if domain == "" or not port or port <= 0 then
		e.error = "missing target"
		write_json(e)
		return
	end

	local resolved_ip = resolve_ipv4(domain)
	if resolved_ip == "" then
		resolved_ip = cached_ipv4_for_domain(domain)
	end
	local target = resolved_ip ~= "" and resolved_ip or domain
	local bypass_state = add_ping_bypass(resolved_ip)

	if transport == "ws" then
		local prefix = tls == "1" and "https://" or "http://"
		local address = prefix .. domain .. ":" .. tostring(port) .. wsPath
		local result = luci.sys.exec(
			"curl --http1.1 -m 3 -ksN -o /dev/null " ..
			"-w 'time_connect=%{time_connect}\nhttp_code=%{http_code}' " ..
			"-H 'Connection: Upgrade' -H 'Upgrade: websocket' " ..
			"-H 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' " ..
			"-H 'Sec-WebSocket-Version: 13' " .. shell_quote(address)
		)
		e.socket = string.match(result, "http_code=(%d+)") == "101"
		e.ping = parse_latency_ms(result)
	else
		if target ~= "" then
			local nping_out = luci.sys.exec("timeout 5 nping --tcp-connect -c 1 -p " .. tostring(port) .. " " .. shell_quote(target) .. " 2>&1")
			e.socket = nping_out:match("Successful connections: 1") ~= nil
			e.ping = parse_latency_ms(nping_out)
		end

		if not e.ping then
			local ping_output = luci.sys.exec("ping -c 1 -W 1 " .. shell_quote(target) .. " 2>/dev/null")
			e.ping = parse_latency_ms(ping_output)
		end
	end

	remove_ping_bypass(bypass_state)
	e.domain = domain
	e.target = target
	write_json(e)
end

function check_status()
	local e = {}
	e.ret = luci.sys.call("/usr/bin/ssr-check www." .. luci.http.formvalue("set") .. ".com 80 3 1")
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function refresh_data()
	local set = luci.http.formvalue("set")
	local retstring = loadstring("return " .. luci.sys.exec("/usr/bin/lua /usr/share/shadowsocksr/update.lua " .. set))()
	luci.http.prepare_content("application/json")
	luci.http.write_json(retstring)
end

function check_port()
	local retstring = "<br /><br />"
	local s
	local server_name = ""
	local uci = require "luci.model.uci".cursor()

	uci:foreach("shadowsocksr", "servers", function(s)
		if s.alias then
			server_name = s.alias
		elseif s.server and s.server_port then
			server_name = s.server .. ":" .. s.server_port
		end

		-- 临时加入 set
		local resolved_ip = resolve_ipv4(s.server)
		local target = resolved_ip ~= "" and resolved_ip or s.server
		local bypass_state = add_ping_bypass(resolved_ip)

		-- TCP 测试
		local socket = nixio.socket("inet", "stream")
		socket:setopt("socket", "rcvtimeo", 3)
		socket:setopt("socket", "sndtimeo", 3)
		local ret = socket:connect(target, s.server_port)
		socket:close()

		if ret then
			retstring = retstring .. string.format("<font><b style='color:green'>[%s] OK.</b></font><br />", server_name)
		else
			retstring = retstring .. string.format("<font><b style='color:red'>[%s] Error.</b></font><br />", server_name)
		end

		-- 删除临时 set
		remove_ping_bypass(bypass_state)
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json({ret = retstring})
end

function act_reset()
	luci.sys.call("/etc/init.d/shadowsocksr reset >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr"))
end

function act_restart()
	apply_stability_preset(require "luci.model.uci".cursor())
	queue_sync_apply("restart", "已提交后台任务，正在重新生效网络")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr"))
end

function act_apply_sync()
	local section = luci.http.formvalue("section")
	local cursor = require "luci.model.uci".cursor()
	local global = cursor:get_first("shadowsocksr", "global")
	if not global then
		cursor:set("shadowsocksr", "global", "global", "global")
		cursor:commit("shadowsocksr")
		global = cursor:get_first("shadowsocksr", "global")
	end
	if section and section ~= "" and global then
		section = normalize_server_section(cursor, section)
		cursor:set("shadowsocksr", global, "global_server", section)
		cursor:commit("shadowsocksr")
	end
	apply_stability_preset(cursor)
	write_json(queue_sync_apply(section and ("node:" .. section) or "apply", section and "节点已保存，后台正在切换代理链路" or "配置已保存，后台正在生效"))
end

function act_apply_split_mode()
	local uci = require "luci.model.uci".cursor()
	local global = uci:get_first("shadowsocksr", "global")
	local access = uci:get_first("shadowsocksr", "access_control")
	local dnsmasq = uci:get_first("dhcp", "dnsmasq")

	if global then
		uci:set("shadowsocksr", global, "run_mode", "router")
		uci:set("shadowsocksr", global, "dports", "1")
	end

	if access then
		uci:set("shadowsocksr", access, "router_proxy", "1")
	end

	if dnsmasq then
		uci:set("dhcp", dnsmasq, "filter_aaaa", "1")
	end
	uci:commit("shadowsocksr")
	uci:commit("dhcp")
	write_json(queue_sync_apply("preset", "分流增强模式已保存，后台正在生效"))
end

function act_quick_flush()
	write_json(queue_sync_apply("rebuild", "已提交后台任务，正在重新生效网络"))
end

function act_flush()
	write_json(queue_sync_apply("rebuild", "已提交后台任务，正在重新生效网络"))
end

function act_flush_hard()
	write_json(queue_sync_apply("hard_rebuild", "已提交后台任务，正在彻底清理残留进程并重启代理"))
end

function act_toggle_ipv6()
	local cursor = require "luci.model.uci".cursor()
	local global = cursor:get_first("shadowsocksr", "global")
	local current = get_ipv6_state(cursor)
	local mode = trim(luci.http.formvalue("mode"))
	local enable = trim(luci.http.formvalue("enable"))
	if mode == "" then
		if enable == "" then
			mode = current.mode == "off" and "manual" or "off"
		elseif enable == "1" then
			mode = "manual"
		else
			mode = "off"
		end
	end
	if mode ~= "off" and mode ~= "auto" and mode ~= "manual" then
		mode = current.mode or "off"
	end
	if global then
		cursor:set("shadowsocksr", global, "ipv6_mode", mode)
		cursor:commit("shadowsocksr")
	end
	local next_state = get_ipv6_state(cursor, mode)
	if mode == "auto" then
		local message = next_state.auto_supported
			and "IPv6 已切换为自动模式，检测到 LAN/WAN6 支持时会自动启用系统 IPv6，AAAA 过滤保持开启"
			or "IPv6 已切换为自动模式，但当前 LAN/WAN6 还不满足启用条件，系统 IPv6 会保持关闭，AAAA 过滤保持开启"
		write_json(queue_sync_apply("ipv6_auto", message))
	elseif mode == "manual" then
		write_json(queue_sync_apply("ipv6_enable", "IPv6 已切换为手动开启，系统 IPv6 将被启用，AAAA 过滤保持开启"))
	else
		write_json(queue_sync_apply("ipv6_disable", "IPv6 已切换为关闭模式，系统 IPv6 将被关闭，AAAA 过滤保持开启"))
	end
end

function act_import_ss()
	local input_path = luci.http.formvalue("path") or "/root/ssrplus-txt"
	local preferred = luci.http.formvalue("preferred") or ""
	local payload = luci.http.formvalue("payload") or ""
	input_path = input_path:gsub("+", " ")
	preferred = preferred:gsub("+", " ")
	payload = payload:gsub("\r\n", "\n")
	local temp_input = ""
	if payload ~= "" then
		temp_input = "/tmp/ssrplus-import-payload.txt"
		nixio.fs.writefile(temp_input, payload)
		input_path = temp_input
	end
	local tmp_log = "/tmp/ssrplus-import.log"
	local command = string.format(
		"/usr/share/shadowsocksr/import-ss-txt.sh %s %s > %s 2>&1",
		shell_quote(input_path),
		shell_quote(preferred),
		shell_quote(tmp_log)
	)
	local ret = luci.sys.call(command)
	local output = nixio.fs.readfile(tmp_log) or ""
	nixio.fs.remove(tmp_log)
	if temp_input ~= "" then
		nixio.fs.remove(temp_input)
	end
	if ret == 0 then
		write_json({
			ok = true,
			phase = "import",
			message = "导入完成，当前运行链路未改动。如需切换，请在“客户端”或“服务器节点”页手动应用。",
			time = now_string(),
			path = input_path,
			preferred = preferred,
			output = output
		})
		return
	end
	write_json({
		ok = false,
		phase = "import",
		message = "导入失败，请检查 txt 路径或 ss:// 内容",
		time = now_string(),
		path = input_path,
		preferred = preferred,
		output = output
	})
end

function act_delete()
	luci.sys.call("/etc/init.d/shadowsocksr restart &")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr", "servers"))
end

function act_delete_selected()
	local sections_raw = luci.http.formvalue("sections") or ""
	local cursor = require "luci.model.uci".cursor()
	local global_server = cursor:get_first("shadowsocksr", "global", "global_server", "nil")
	local deleted = 0
	local skipped = 0
	for section in sections_raw:gmatch("[^,]+") do
		section = section:gsub("^%s+", ""):gsub("%s+$", "")
		if section ~= "" then
			if section == global_server then
				skipped = skipped + 1
			elseif cursor:get("shadowsocksr", section) then
				cursor:delete("shadowsocksr", section)
				deleted = deleted + 1
			end
		end
	end
	if deleted > 0 then
		cursor:commit("shadowsocksr")
	end
	write_json({
		ok = true,
		deleted = deleted,
		skipped = skipped,
		message = string.format("已删除 %d 个节点", deleted) ..
			(skipped > 0 and string.format("，跳过 %d 个（当前活跃节点）", skipped) or "")
	})
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/ssrplus.log' ] && cat /var/log/ssrplus.log"))
end
	
function clear_log()
	luci.sys.call("echo '' > /var/log/ssrplus.log")
end

function create_backup()
	local backup_files = {
		"/etc/config/shadowsocksr",
		"/etc/ssrplus/*"
	}
	local date = os.date("%Y-%m-%d-%H-%M-%S")
	local tar_file = "/tmp/shadowsocksr-" .. date .. "-backup.tar.gz"
	nixio.fs.remove(tar_file)
	local cmd = "tar -czf " .. tar_file .. " " .. table.concat(backup_files, " ")
	luci.sys.call(cmd)
	luci.http.header("Content-Disposition", "attachment; filename=shadowsocksr-" .. date .. "-backup.tar.gz")
	luci.http.header("X-Backup-Filename", "shadowsocksr-" .. date .. "-backup.tar.gz")
	luci.http.prepare_content("application/octet-stream")
	luci.http.write(nixio.fs.readfile(tar_file))
	nixio.fs.remove(tar_file)
end

function export_full_backup()
	local backup_files = {
		"/etc/config/shadowsocksr",
		"/etc/config/dhcp",
		"/etc/ssrplus/*",
		"/usr/share/shadowsocksr/sync-apply.lua",
		"/usr/share/shadowsocksr/windows-clash-recover.ps1",
		"/usr/share/shadowsocksr/restart-fast.sh",
		"/usr/share/shadowsocksr/restart-enhanced.sh",
		"/usr/share/shadowsocksr/import-ss-txt.sh",
		"/usr/share/shadowsocksr/ssrplus-enhanced-installer.run",
		"/usr/lib/lua/luci/controller/shadowsocksr.lua",
		"/usr/lib/lua/luci/model/cbi/shadowsocksr/client.lua",
		"/usr/lib/lua/luci/model/cbi/shadowsocksr/servers.lua",
		"/usr/lib/lua/luci/view/shadowsocksr/status.htm",
		"/usr/lib/lua/luci/view/shadowsocksr/server_tools.htm",
		"/usr/lib/lua/luci/view/shadowsocksr/server_list.htm",
		"/usr/lib/lua/luci/view/shadowsocksr/ping.htm",
		"/root/ssrplus-txt"
	}
	local date = os.date("%Y-%m-%d-%H-%M-%S")
	local tar_file = "/tmp/shadowsocksr-enhanced-" .. date .. "-backup.tar.gz"
	nixio.fs.remove(tar_file)
	local cmd = "tar -czf " .. tar_file .. " " .. table.concat(backup_files, " ") .. " 2>/dev/null"
	luci.sys.call(cmd)
	luci.http.header("Content-Disposition", "attachment; filename=shadowsocksr-enhanced-" .. date .. "-backup.tar.gz")
	luci.http.header("X-Backup-Filename", "shadowsocksr-enhanced-" .. date .. "-backup.tar.gz")
	luci.http.prepare_content("application/octet-stream")
	luci.http.write(nixio.fs.readfile(tar_file))
	nixio.fs.remove(tar_file)
end

function export_installer()
	local file = "/usr/share/shadowsocksr/ssrplus-enhanced-installer.run"
	if not nixio.fs.access(file) then
		write_json({ ok = false, message = "安装包不存在" })
		return
	end
	luci.http.header("Content-Disposition", "attachment; filename=ssrplus-enhanced-installer.run")
	luci.http.prepare_content("application/octet-stream")
	luci.http.write(nixio.fs.readfile(file))
end

function export_windows_recover()
	if not nixio.fs.access(WINDOWS_RECOVER_FILE) then
		write_json({ ok = false, message = "Windows 恢复脚本不存在" })
		return
	end
	luci.http.header("Content-Disposition", "attachment; filename=windows-clash-recover.ps1")
	luci.http.prepare_content("text/plain")
	luci.http.write(nixio.fs.readfile(WINDOWS_RECOVER_FILE))
end
