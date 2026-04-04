param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'ssrplus-enhanced-installer.run')
)

$ErrorActionPreference = 'Stop'

$files = @(
    @{
        Source = (Join-Path $PSScriptRoot 'shadowsocksr.lua')
        Target = '/usr/lib/lua/luci/controller/shadowsocksr.lua'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'client.lua')
        Target = '/usr/lib/lua/luci/model/cbi/shadowsocksr/client.lua'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'servers.lua')
        Target = '/usr/lib/lua/luci/model/cbi/shadowsocksr/servers.lua'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'status.htm')
        Target = '/usr/lib/lua/luci/view/shadowsocksr/status.htm'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'server_tools.htm')
        Target = '/usr/lib/lua/luci/view/shadowsocksr/server_tools.htm'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'server_list.htm')
        Target = '/usr/lib/lua/luci/view/shadowsocksr/server_list.htm'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'ping.htm')
        Target = '/usr/lib/lua/luci/view/shadowsocksr/ping.htm'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'sync-apply.lua')
        Target = '/usr/share/shadowsocksr/sync-apply.lua'
        Mode   = '0755'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'windows-clash-recover.ps1')
        Target = '/usr/share/shadowsocksr/windows-clash-recover.ps1'
        Mode   = '0644'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'restart-fast.sh')
        Target = '/usr/share/shadowsocksr/restart-fast.sh'
        Mode   = '0755'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'restart-enhanced.sh')
        Target = '/usr/share/shadowsocksr/restart-enhanced.sh'
        Mode   = '0755'
    },
    @{
        Source = (Join-Path $PSScriptRoot 'import-ss-txt.sh')
        Target = '/usr/share/shadowsocksr/import-ss-txt.sh'
        Mode   = '0755'
    }
)

function Get-FileBase64([string]$Path) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $content = [System.IO.File]::ReadAllText($Path, $encoding)
    return [Convert]::ToBase64String($encoding.GetBytes($content))
}

$lines = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines.Add('#!/bin/sh')
$lines.Add('set -eu')
$lines.Add('')
$lines.Add('SCRIPT_NAME="$(basename "$0")"')
$lines.Add('BACKUP_DIR="/root/ssrplus-enhanced-install-backup-$(date +%Y%m%d-%H%M%S)"')
$lines.Add('mkdir -p "$BACKUP_DIR"')
$lines.Add('')
$lines.Add('log() {')
$lines.Add('  printf ''%s\n'' "[SSRPLUS-INSTALL] $*"')
$lines.Add('}')
$lines.Add('')
$lines.Add('backup_file() {')
$lines.Add('  src="$1"')
$lines.Add('  if [ -f "$src" ]; then')
$lines.Add('    dst="$BACKUP_DIR$src"')
$lines.Add('    mkdir -p "$(dirname "$dst")"')
$lines.Add('    cp "$src" "$dst"')
$lines.Add('  fi')
$lines.Add('}')
$lines.Add('')
$lines.Add('write_b64_file() {')
$lines.Add('  target="$1"')
$lines.Add('  mode="$2"')
$lines.Add('  tmp="$(mktemp)"')
$lines.Add('  mkdir -p "$(dirname "$target")"')
$lines.Add('  cat > "$tmp.b64"')
$lines.Add('  base64 -d "$tmp.b64" > "$target"')
$lines.Add('  chmod "$mode" "$target"')
$lines.Add('  rm -f "$tmp.b64"')
$lines.Add('}')
$lines.Add('')
$lines.Add('log "Installing enhanced SSR Plus+ files"')

foreach ($file in $files) {
    if (-not (Test-Path $file.Source)) {
        throw "Missing source file: $($file.Source)"
    }
    $lines.Add("backup_file '$($file.Target)'")
}

$lines.Add('')

foreach ($file in $files) {
    $lines.Add("write_b64_file '$($file.Target)' '$($file.Mode)' <<'__SSRPLUS_B64__'")
    $lines.Add((Get-FileBase64 $file.Source))
    $lines.Add('__SSRPLUS_B64__')
    $lines.Add('')
}

$lines.Add('mkdir -p /root/ssrplus-txt')
$lines.Add('uci set dhcp.@dnsmasq[0].filter_aaaa=''1''')
$lines.Add('uci commit dhcp')
$lines.Add('/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true')
$lines.Add('cp "$0" /usr/share/shadowsocksr/ssrplus-enhanced-installer.run')
$lines.Add('chmod 0755 /usr/share/shadowsocksr/ssrplus-enhanced-installer.run')
$lines.Add('rm -f /tmp/luci-indexcache')
$lines.Add('rm -rf /tmp/luci-modulecache/* 2>/dev/null || true')
$lines.Add('/etc/init.d/uhttpd restart >/dev/null 2>&1 || true')
$lines.Add('log "Install finished"')
$lines.Add('log "Backup dir: $BACKUP_DIR"')
$lines.Add('log "TXT import path: /root/ssrplus-txt"')
$lines.Add('log "DNS AAAA filter: enabled (dhcp.@dnsmasq[0].filter_aaaa=1)"')
$lines.Add('log "Client page now supports: computer mode toggle, sync apply, txt import, export full backup, export installer, Windows recover script"')
$lines.Add('exit 0')

[System.IO.File]::WriteAllText($OutputPath, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Output "Built installer: $OutputPath"
Write-Output "Build time: $stamp"
