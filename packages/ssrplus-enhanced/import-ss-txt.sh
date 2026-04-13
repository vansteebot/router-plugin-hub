#!/bin/sh

set -eu

DEFAULT_INPUT="/root/ssrplus-txt"
INPUT_PATH="${1:-$DEFAULT_INPUT}"
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

find_existing_section() {
	local server="$1"
	local port="$2"
	local section current_server current_port

	for section in $(uci show shadowsocksr | sed -n "s/^shadowsocksr\.\([^.=]*\)=servers$/\1/p"); do
		current_server="$(uci -q get "shadowsocksr.$section.server" || true)"
		current_port="$(uci -q get "shadowsocksr.$section.server_port" || true)"
		if [ "$current_server" = "$server" ] && [ "$current_port" = "$port" ]; then
			printf '%s\n' "$section"
			return 0
		fi
	done

	return 1
}

trap cleanup EXIT INT TERM

need_cmd uci
need_cmd lua
need_cmd find

mkdir -p "$BACKUP_DIR" "$TMP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
uci export shadowsocksr > "$BACKUP_DIR/shadowsocksr-$STAMP.uci"

cat > "$PARSE_LUA" <<'LUA'
local input = arg[1]
local output = arg[2]

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
  alias = alias:gsub("^%s+", ""):gsub("%s+$", "")
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

UPDATED=0
CREATED=0
TAB="$(printf '\t')"

while IFS="$TAB" read -r SERVER PORT CIPHER PASSWORD PLUGIN PLUGIN_OPTS ALIAS; do
	[ -n "$SERVER" ] || continue

	if SECTION="$(find_existing_section "$SERVER" "$PORT")"; then
		UPDATED=$((UPDATED + 1))
	else
		SECTION="$(uci add shadowsocksr servers)"
		CREATED=$((CREATED + 1))
	fi

	uci set "shadowsocksr.$SECTION.type=ss"
	uci set "shadowsocksr.$SECTION.server=$SERVER"
	uci set "shadowsocksr.$SECTION.server_port=$PORT"
	uci set "shadowsocksr.$SECTION.password=$PASSWORD"
	uci set "shadowsocksr.$SECTION.encrypt_method_ss=$CIPHER"
	uci set "shadowsocksr.$SECTION.alias=$ALIAS"
	uci set "shadowsocksr.$SECTION.switch_enable=0"

	if ! uci -q get "shadowsocksr.$SECTION.local_port" >/dev/null 2>&1; then
		uci set "shadowsocksr.$SECTION.local_port=1234"
	fi
	if ! uci -q get "shadowsocksr.$SECTION.kcp_param" >/dev/null 2>&1; then
		uci set "shadowsocksr.$SECTION.kcp_param=--nocomp"
	fi
	if ! uci -q get "shadowsocksr.$SECTION.has_ss_type" >/dev/null 2>&1; then
		uci set "shadowsocksr.$SECTION.has_ss_type=ss-rust"
	fi

	if [ -n "$PLUGIN" ]; then
		uci set "shadowsocksr.$SECTION.enable_plugin=1"
		uci set "shadowsocksr.$SECTION.plugin=$PLUGIN"
		uci set "shadowsocksr.$SECTION.plugin_opts=$PLUGIN_OPTS"
	else
		uci set "shadowsocksr.$SECTION.enable_plugin=0"
		uci -q delete "shadowsocksr.$SECTION.plugin" >/dev/null 2>&1 || true
		uci -q delete "shadowsocksr.$SECTION.plugin_opts" >/dev/null 2>&1 || true
	fi

done < "$PARSED_TSV"

uci commit shadowsocksr

# Ensure server_subscribe.ss_type is set — the init script reads this (NOT the per-node
# has_ss_type) to decide which binary to start. Without it, sslocal never starts but
# nftables redirect rules are still applied, causing complete internet loss.
current_ss_type="$(uci -q get shadowsocksr.@server_subscribe[0].ss_type 2>/dev/null || true)"
if [ -z "$current_ss_type" ]; then
	uci set shadowsocksr.@server_subscribe[0].ss_type='ss-rust' 2>/dev/null || true
	uci commit shadowsocksr 2>/dev/null || true
	log "Set server_subscribe.ss_type=ss-rust (was missing)"
fi

log "Imported nodes: $COUNT"
log "Created: $CREATED"
log "Updated: $UPDATED"
log "Import finished. Nodes imported only, runtime chain was not restarted."
