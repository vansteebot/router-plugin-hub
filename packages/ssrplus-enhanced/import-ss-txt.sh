#!/bin/sh

set -eu

SCRIPT_NAME="$(basename "$0")"
DEFAULT_INPUT="/root/ssrplus-txt"
INPUT_PATH="${1:-$DEFAULT_INPUT}"
PREFERRED_NODE="${2:-}"
BACKUP_DIR="/root/ssrplus-enhanced-backup"
TMP_DIR="/tmp/ssrplus-import"
PARSED_TSV="$TMP_DIR/parsed.tsv"
PARSE_LUA="$TMP_DIR/parse_ss.lua"

log() {
	printf '%s\n' "[SSR-IMPORT] $*"
}

die() {
	printf '%s\n' "[SSR-IMPORT][ERROR] $*" >&2
	exit 1
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

cleanup() {
	rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

need_cmd uci
need_cmd lua
need_cmd find

[ -x /etc/init.d/shadowsocksr ] || die "shadowsocksr init script not found"
[ -x /usr/share/shadowsocksr/restart-enhanced.sh ] || die "restart-enhanced.sh not found"

mkdir -p "$BACKUP_DIR" "$TMP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"

uci export shadowsocksr > "$BACKUP_DIR/shadowsocksr-$STAMP.uci"

cat > "$PARSE_LUA" <<'LUA'
local input = arg[1]
local output = arg[2]

local map = {
  ["hk01.hkss.online"] = "HK 1",
  ["hko2.hkss.online"] = "HK 2",
  ["hk3.hkss.online"] = "HK 3",
  ["node-hkcn2.hkss.online"] = "HK 4",
  ["kagoya.hkss.online"] = "JP Japan",
  ["node-hktous.hkss.online"] = "US America",
  ["node-hktous2.hkss.online"] = "US America 2",
  ["tw-hinet1.hkss.online"] = "Taiwan TW",
  ["sgp-1.hkss.online"] = "Singapore SGP",
  ["hkp-1.hkss.online"] = "HK Premium 1",
  ["hkp-2.hkss.online"] = "HK Premium 2",
  ["hkp-3.hkss.online"] = "HK Premium 3",
  ["node-hk6.hkss.online"] = "HK6 Unlimited",
  ["node-hktims.hkss.online"] = "HK8 Annual 1",
  ["hktims2.hkss.online"] = "HK8 Annual 2",
  ["kagoya2.hkss.online"] = "JP VIP2"
}

local function urldecode(s)
  s = s or ""
  s = s:gsub("+", " ")
  s = s:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return s
end

local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64decode(data)
  data = (data or ""):gsub("%s+", "")
  local pad = #data % 4
  if pad > 0 then
    data = data .. string.rep("=", 4 - pad)
  end
  data = data:gsub("[^" .. b .. "=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then
      return ""
    end
    local r, f = "", (b:find(x, 1, true) or 1) - 1
    for i = 6, 1, -1 do
      r = r .. ((f % 2 ^ i - f % 2 ^ (i - 1) > 0) and "1" or "0")
    end
    return r
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
    if #x ~= 8 then
      return ""
    end
    local c = 0
    for i = 1, 8 do
      if x:sub(i, i) == "1" then
        c = c + 2 ^ (8 - i)
      end
    end
    return string.char(c)
  end))
end

local function clean_alias(tag, server)
  local alias = urldecode(tag or "")
  alias = alias:gsub("^HKSSNetwork%s*%-%s*", "")
  alias = alias:gsub("^%s+", ""):gsub("%s+$", "")
  if map[server] then
    return map[server]
  end
  if alias == "" then
    alias = server
  end
  alias = alias:gsub("[\r\n\t]", " ")
  alias = alias:gsub("%s+", " ")
  return alias
end

local files = {}
local p = io.popen("find " .. string.format("%q", input) .. " -type f \\( -name '*.txt' -o -name '*.list' \\) 2>/dev/null")
if p then
  for line in p:lines() do
    files[#files + 1] = line
  end
  p:close()
end

if #files == 0 then
  local probe = io.popen("test -f " .. string.format("%q", input) .. " && echo file")
  if probe then
    local marker = probe:read("*l")
    probe:close()
    if marker == "file" then
      files[#files + 1] = input
    end
  end
end

if #files == 0 then
  io.stderr:write("no input files found\n")
  os.exit(2)
end

table.sort(files)

local out = assert(io.open(output, "w"))
local seen = {}
local count = 0

for _, file in ipairs(files) do
  local fh = io.open(file, "r")
  if fh then
    for raw in fh:lines() do
      local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
      if line:match("^ss://") then
        local body = line:sub(6)
        local tag = ""
        local hash = body:find("#", 1, true)
        if hash then
          tag = body:sub(hash + 1)
          body = body:sub(1, hash - 1)
        end
        local query = ""
        local qm = body:find("?", 1, true)
        if qm then
          query = body:sub(qm + 1)
          body = body:sub(1, qm - 1)
        end
        local creds, hostpart = body:match("^(.-)@(.*)$")
        if creds and hostpart then
          local decoded = b64decode(creds)
          local cipher, password = decoded:match("^([^:]+):(.+)$")
          local server, port = hostpart:match("^(.-):(%d+)$")
          if cipher and password and server and port then
            local params = {}
            for k, v in query:gmatch("([^&=?]+)=([^&]*)") do
              params[urldecode(k)] = urldecode(v)
            end
            local plugin = ""
            local plugin_opts = ""
            if params.plugin and params.plugin ~= "" then
              local first, rest = params.plugin:match("^([^;]+);?(.*)$")
              plugin = first or ""
              plugin_opts = rest or ""
            end
            local alias = clean_alias(tag, server)
            local key = server .. ":" .. port
            if not seen[key] then
              seen[key] = true
              out:write(table.concat({
                server,
                port,
                cipher,
                password,
                plugin,
                plugin_opts,
                alias
              }, "\t"))
              out:write("\n")
              count = count + 1
            end
          end
        end
      end
    end
    fh:close()
  end
end

out:close()

if count == 0 then
  io.stderr:write("no valid ss:// lines found\n")
  os.exit(3)
end

print(count)
LUA

COUNT="$(lua "$PARSE_LUA" "$INPUT_PATH" "$PARSED_TSV")" || die "Failed to parse input"
[ -s "$PARSED_TSV" ] || die "No valid ss:// lines found in $INPUT_PATH"

if uci -q get openclash.config.enable >/dev/null 2>&1; then
	uci set openclash.config.enable='0'
	uci commit openclash
	/etc/init.d/openclash stop >/dev/null 2>&1 || true
	killall clash mihomo >/dev/null 2>&1 || true
fi

/etc/init.d/shadowsocksr stop >/dev/null 2>&1 || true
killall ss-redir sslocal obfs-local dns2tcp dns2socks pdnsd >/dev/null 2>&1 || true

while uci -q delete shadowsocksr.@servers[0] >/dev/null 2>&1; do :; done

FIRST_SECTION=""
SELECTED_SECTION=""
TAB="$(printf '\t')"

while IFS="$TAB" read -r SERVER PORT CIPHER PASSWORD PLUGIN PLUGIN_OPTS ALIAS; do
	[ -n "$SERVER" ] || continue
	SECTION="$(uci add shadowsocksr servers)"
	[ -n "$FIRST_SECTION" ] || FIRST_SECTION="$SECTION"

	uci set "shadowsocksr.$SECTION.type=ss"
	uci set "shadowsocksr.$SECTION.server=$SERVER"
	uci set "shadowsocksr.$SECTION.server_port=$PORT"
	uci set "shadowsocksr.$SECTION.password=$PASSWORD"
	uci set "shadowsocksr.$SECTION.encrypt_method_ss=$CIPHER"
	uci set "shadowsocksr.$SECTION.local_port=1234"
	uci set "shadowsocksr.$SECTION.kcp_param=--nocomp"
	uci set "shadowsocksr.$SECTION.switch_enable=1"
	uci set "shadowsocksr.$SECTION.alias=$ALIAS"
	uci set "shadowsocksr.$SECTION.has_ss_type=ss-rust"

	if [ -n "$PLUGIN" ]; then
		uci set "shadowsocksr.$SECTION.enable_plugin=1"
		uci set "shadowsocksr.$SECTION.plugin=$PLUGIN"
		uci set "shadowsocksr.$SECTION.plugin_opts=$PLUGIN_OPTS"
	else
		uci set "shadowsocksr.$SECTION.enable_plugin=0"
		uci -q delete "shadowsocksr.$SECTION.plugin" >/dev/null 2>&1 || true
		uci -q delete "shadowsocksr.$SECTION.plugin_opts" >/dev/null 2>&1 || true
	fi

	if [ -n "$PREFERRED_NODE" ] && [ -z "$SELECTED_SECTION" ]; then
		if printf '%s\n' "$ALIAS|$SERVER" | grep -Fqi -- "$PREFERRED_NODE"; then
			SELECTED_SECTION="$SECTION"
		fi
	fi
done < "$PARSED_TSV"

[ -n "$FIRST_SECTION" ] || die "No nodes were imported"

if [ -n "$PREFERRED_NODE" ]; then
	for SECTION in $(uci show shadowsocksr | sed -n 's/^shadowsocksr\.\([^.=]*\)=servers$/\1/p'); do
		ALIAS_VALUE="$(uci -q get shadowsocksr.$SECTION.alias || true)"
		SERVER_VALUE="$(uci -q get shadowsocksr.$SECTION.server || true)"
		if printf '%s\n' "$ALIAS_VALUE|$SERVER_VALUE" | grep -Fqi -- "$PREFERRED_NODE"; then
			SELECTED_SECTION="$SECTION"
			break
		fi
	done
fi

[ -n "$SELECTED_SECTION" ] || SELECTED_SECTION="$FIRST_SECTION"

uci set shadowsocksr.@global[0].global_server="$SELECTED_SECTION"
uci set shadowsocksr.@global[0].run_mode='router'
uci set shadowsocksr.@global[0].dports='2'
uci set shadowsocksr.@global[0].pdnsd_enable='1'
uci set shadowsocksr.@global[0].tunnel_forward='8.8.4.4:53'
uci -q get shadowsocksr.@global[0].enable_switch >/dev/null 2>&1 || uci set shadowsocksr.@global[0].enable_switch='0'
uci -q get shadowsocksr.@global[0].monitor_enable >/dev/null 2>&1 || uci set shadowsocksr.@global[0].monitor_enable='1'
uci -q get shadowsocksr.@global[0].switch_time >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_time='30'
uci -q get shadowsocksr.@global[0].switch_timeout >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_timeout='3'
uci -q get shadowsocksr.@global[0].switch_try_count >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_try_count='0'
uci -q get shadowsocksr.@global[0].switch_window_seconds >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_window_seconds='300'
uci -q get shadowsocksr.@global[0].switch_window_failures >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_window_failures='10'
uci -q get shadowsocksr.@global[0].switch_cooldown >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_cooldown='300'
uci -q get shadowsocksr.@global[0].switch_probe_host >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_probe_host='www.google.com'
uci -q get shadowsocksr.@global[0].switch_probe_port >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_probe_port='80'
uci set shadowsocksr.@global[0].safe_dns_tcp='1'
uci set shadowsocksr.@global[0].ipv6_mode='off'
uci set shadowsocksr.@access_control[0].router_proxy='1'
uci set network.wan6.disabled='1'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.ra_slaac='0'
uci set dhcp.lan.ra_default='0'
uci set dhcp.@dnsmasq[0].filter_aaaa='1'
uci set shadowsocksr.@socks5_proxy[0].server="$SELECTED_SECTION"
uci set shadowsocksr.@socks5_proxy[0].local_port='1080'

if uci -q get shadowsocksr.@server_subscribe[0] >/dev/null 2>&1; then
	uci set shadowsocksr.@server_subscribe[0].auto_update='0'
	uci set shadowsocksr.@server_subscribe[0].switch='0'
fi

uci commit shadowsocksr
uci commit network
uci commit dhcp
/etc/init.d/network reload >/dev/null 2>&1 || true
/etc/init.d/odhcpd restart >/dev/null 2>&1 || true
/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
/usr/share/shadowsocksr/restart-enhanced.sh
sleep 4

ACTIVE_SECTION="$(uci -q get shadowsocksr.@global[0].global_server || true)"
ACTIVE_ALIAS="$(uci -q get shadowsocksr.$ACTIVE_SECTION.alias || true)"
ACTIVE_SERVER="$(uci -q get shadowsocksr.$ACTIVE_SECTION.server || true)"
ACTIVE_PORT="$(uci -q get shadowsocksr.$ACTIVE_SECTION.server_port || true)"
ACTIVE_SUMMARY="${ACTIVE_ALIAS}|${ACTIVE_SERVER}|${ACTIVE_PORT}"

IP_CHECK="$(curl -4 -m 10 -fsSL https://api.ip.sb/ip 2>/dev/null || true)"

log "Imported node count: ${COUNT:-unknown}"
log "Requested preferred: ${PREFERRED_NODE:-<none>}"
log "Selected section: ${SELECTED_SECTION:-<none>}"
log "Active node: ${ACTIVE_SUMMARY:-$ACTIVE_SECTION}"
if [ -n "$IP_CHECK" ]; then
	log "Exit IP: $IP_CHECK"
fi
