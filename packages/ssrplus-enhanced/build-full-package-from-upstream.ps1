param(
    [string]$Version = (Get-Date -Format 'yyyyMMdd'),
    [string]$Arch = 'aarch64_cortex-a53-190',
    [string]$BaseRelease = 'r126',
    [string]$UpstreamRunPath = 'C:\Users\Admin\Downloads\ssrp_aarch64_cortex-a53-190_r126.upstream.run',
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'release')
)

$ErrorActionPreference = 'Stop'

$packageBaseName = "ssrp_${Arch}_${BaseRelease}_enhanced_full_${Version}"
$releaseDir = Join-Path $OutputRoot $packageBaseName
$installerPath = Join-Path $releaseDir ($packageBaseName + '.run')
$shaPath = Join-Path $releaseDir 'SHA256SUMS.txt'
$readmePath = Join-Path $releaseDir 'README.md'

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ssrplus-full-release-" + [Guid]::NewGuid().ToString('N'))
$upstreamExtractDir = Join-Path $stageRoot 'upstream'
$packageRoot = Join-Path $stageRoot 'package'
$overlayRoot = Join-Path $packageRoot 'overlay'
$tarballPath = Join-Path $stageRoot 'payload.tar.gz'

$files = @(
    @{ Source = 'shadowsocksr.lua';            Target = '/usr/lib/lua/luci/controller/shadowsocksr.lua';               Mode = '0644' }
    @{ Source = 'client.lua';                  Target = '/usr/lib/lua/luci/model/cbi/shadowsocksr/client.lua';         Mode = '0644' }
    @{ Source = 'client-config.lua';           Target = '/usr/lib/lua/luci/model/cbi/shadowsocksr/client-config.lua';  Mode = '0644' }
    @{ Source = 'servers.lua';                 Target = '/usr/lib/lua/luci/model/cbi/shadowsocksr/servers.lua';        Mode = '0644' }
    @{ Source = 'status.htm';                  Target = '/usr/lib/lua/luci/view/shadowsocksr/status.htm';              Mode = '0644' }
    @{ Source = 'status_bottom.htm';           Target = '/usr/lib/lua/luci/view/shadowsocksr/status_bottom.htm';       Mode = '0644' }
    @{ Source = 'server_tools.htm';            Target = '/usr/lib/lua/luci/view/shadowsocksr/server_tools.htm';        Mode = '0644' }
    @{ Source = 'server_list.htm';             Target = '/usr/lib/lua/luci/view/shadowsocksr/server_list.htm';         Mode = '0644' }
    @{ Source = 'ping.htm';                    Target = '/usr/lib/lua/luci/view/shadowsocksr/ping.htm';                Mode = '0644' }
    @{ Source = 'sync-apply.lua';              Target = '/usr/share/shadowsocksr/sync-apply.lua';                      Mode = '0755' }
    @{ Source = 'restart-fast.sh';             Target = '/usr/share/shadowsocksr/restart-fast.sh';                     Mode = '0755' }
    @{ Source = 'restart-enhanced.sh';         Target = '/usr/share/shadowsocksr/restart-enhanced.sh';                 Mode = '0755' }
    @{ Source = 'import-ss-txt.sh';            Target = '/usr/share/shadowsocksr/import-ss-txt.sh';                    Mode = '0755' }
    @{ Source = 'windows-clash-recover.ps1';   Target = '/usr/share/shadowsocksr/windows-clash-recover.ps1';           Mode = '0644' }
    @{ Source = 'gfw2ipset.remote.sh';         Target = '/usr/share/shadowsocksr/gfw2ipset.sh';                        Mode = '0755' }
    @{ Source = 'shadowsocksr.init.remote.sh'; Target = '/etc/init.d/shadowsocksr';                                    Mode = '0755' }
    @{ Source = 'ssr-switch.remote.sh';        Target = '/usr/bin/ssr-switch';                                         Mode = '0755' }
    @{ Source = 'ssr-rules.remote.sh';         Target = '/usr/bin/ssr-rules';                                          Mode = '0755' }
    @{ Source = 'ssrplus-persistence-check.cron';Target = '/etc/cron.d/ssrplus-persistence-check';                     Mode = '0644' }
)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# Copy a text file with LF normalization (CRLF -> LF) and strip BOM if any.
# Linux-only consumers (sh, lua, LuCI templates) trip over CRLF:
#   - LuCI's C-based template parser raises "unfinished string near ..." when an
#     HTML-leading .htm (no <% block at start) has CRLF line endings.
#   - /bin/sh interprets the trailing \r as part of arguments.
function Copy-TextFile-Lf([string]$Source, [string]$Dest) {
    $bytes = [System.IO.File]::ReadAllBytes($Source)
    # Strip UTF-8 BOM if present
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }
    # CRLF -> LF
    $out = New-Object System.Collections.Generic.List[byte] $bytes.Length
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $b = $bytes[$i]
        if ($b -eq 13 -and ($i + 1) -lt $bytes.Length -and $bytes[$i + 1] -eq 10) { continue }  # skip CR before LF
        $out.Add($b)
    }
    [System.IO.File]::WriteAllBytes($Dest, $out.ToArray())
}

function Assert-FileExists([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
}

function Get-RelativeUnixPath([string]$AbsoluteUnixPath) {
    return $AbsoluteUnixPath.TrimStart('/')
}

Assert-FileExists $UpstreamRunPath
Assert-FileExists (Join-Path $PSScriptRoot 'extract_makeself.py')

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
New-Item -ItemType Directory -Force -Path $upstreamExtractDir | Out-Null

Write-Host "[1/5] Extracting upstream full package..."
& python (Join-Path $PSScriptRoot 'extract_makeself.py') $UpstreamRunPath $upstreamExtractDir

$upstreamPayload = Join-Path $upstreamExtractDir 'payload'
Assert-FileExists (Join-Path $upstreamPayload 'install.sh')
Assert-FileExists (Join-Path $upstreamPayload 'luci-app-ssr-plus_190-r126_all.ipk')
Assert-FileExists (Join-Path $upstreamPayload 'depends')

Write-Host "[2/5] Preparing full package root..."
Copy-Item -Recurse -Force $upstreamPayload $packageRoot
Move-Item -Force (Join-Path $packageRoot 'install.sh') (Join-Path $packageRoot 'install.upstream.sh')
New-Item -ItemType Directory -Force -Path $overlayRoot | Out-Null

foreach ($file in $files) {
    $sourcePath = Join-Path $PSScriptRoot $file.Source
    Assert-FileExists $sourcePath

    $relativeTarget = Get-RelativeUnixPath $file.Target
    $targetPath = Join-Path $overlayRoot $relativeTarget
    $targetDir = Split-Path -Parent $targetPath
    if ($targetDir) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    Copy-TextFile-Lf $sourcePath $targetPath
}

$installLines = New-Object System.Collections.Generic.List[string]
$installLines.Add('#!/bin/sh')
$installLines.Add('set -u')
$installLines.Add('')
$installLines.Add('PKG_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"')
$installLines.Add('OVERLAY_DIR="$PKG_DIR/overlay"')
$installLines.Add('BACKUP_DIR="/root/ssrplus-enhanced-install-backup-$(date +%Y%m%d-%H%M%S)"')
$installLines.Add('mkdir -p "$BACKUP_DIR"')
$installLines.Add('')
$installLines.Add('log() {')
$installLines.Add('  printf ''%s\n'' "[SSRPLUS-INSTALL] $*"')
$installLines.Add('}')
$installLines.Add('')
$installLines.Add('backup_file() {')
$installLines.Add('  src="$1"')
$installLines.Add('  if [ -f "$src" ]; then')
$installLines.Add('    dst="$BACKUP_DIR$src"')
$installLines.Add('    mkdir -p "$(dirname "$dst")"')
$installLines.Add('    cp "$src" "$dst"')
$installLines.Add('  fi')
$installLines.Add('}')
$installLines.Add('')
$installLines.Add('install_file() {')
$installLines.Add('  src="$1"')
$installLines.Add('  dst="$2"')
$installLines.Add('  mode="$3"')
$installLines.Add('  mkdir -p "$(dirname "$dst")"')
$installLines.Add('  cp "$src" "$dst"')
$installLines.Add('  chmod "$mode" "$dst"')
$installLines.Add('}')
$installLines.Add('')
$installLines.Add('log "Installing upstream full package..."')
$installLines.Add('chmod +x "$PKG_DIR/install.upstream.sh"')
$installLines.Add('( cd "$PKG_DIR" && ./install.upstream.sh ) || log "WARNING: upstream install reported errors (may be non-fatal)"')
$installLines.Add('')
$installLines.Add('log "Applying enhanced overlay..."')
foreach ($file in $files) {
    $installLines.Add("backup_file '$($file.Target)'")
}
$installLines.Add('')
foreach ($file in $files) {
    $relativeTarget = Get-RelativeUnixPath $file.Target
    $installLines.Add(("install_file ""`$OVERLAY_DIR/{0}"" '{1}' '{2}'" -f $relativeTarget, $file.Target, $file.Mode))
}
$installLines.Add('')
$installLines.Add('mkdir -p /root/ssrplus-txt')
$installLines.Add('uci -q get shadowsocksr.@global[0].enable_switch >/dev/null 2>&1 || uci set shadowsocksr.@global[0].enable_switch=''0'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].monitor_enable >/dev/null 2>&1 || uci set shadowsocksr.@global[0].monitor_enable=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_time >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_time=''30'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_timeout >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_timeout=''3'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_try_count >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_try_count=''0'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_window_seconds >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_window_seconds=''300'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_window_failures >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_window_failures=''10'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_cooldown >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_cooldown=''300'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_probe_host >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_probe_host=''www.google.com'' >/dev/null 2>&1 || true')
$installLines.Add('uci -q get shadowsocksr.@global[0].switch_probe_port >/dev/null 2>&1 || uci set shadowsocksr.@global[0].switch_probe_port=''80'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].threads=''0'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].run_mode=''router'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].dports=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].ipv6_mode=''off'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@access_control[0].router_proxy=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@server_subscribe[0].ss_type=''ss-rust'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@server_subscribe[0].allow_insecure=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].pdnsd_enable=''2'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].tunnel_forward=''8.8.8.8:53'' >/dev/null 2>&1 || true')
$installLines.Add('# chinadns-ng must query the trusted upstream over TCP, not UDP — UDP queries to')
$installLines.Add('# 1.1.1.1/8.8.8.8 from inside China get GFW-spoofed responses (e.g. www.google.com')
$installLines.Add('# resolved as a Twitter/Facebook IP), making Google/YouTube unreachable from HK exits.')
$installLines.Add('uci set shadowsocksr.@global[0].chinadns_ng_proto=''tcp'' >/dev/null 2>&1 || true')
$installLines.Add('uci set shadowsocksr.@global[0].safe_dns_tcp=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci set network.wan6.disabled=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci set dhcp.lan.dhcpv6=''disabled'' >/dev/null 2>&1 || true')
$installLines.Add('uci set dhcp.lan.ra=''disabled'' >/dev/null 2>&1 || true')
$installLines.Add('uci set dhcp.lan.ra_slaac=''0'' >/dev/null 2>&1 || true')
$installLines.Add('uci set dhcp.lan.ra_default=''0'' >/dev/null 2>&1 || true')
$installLines.Add('uci set dhcp.@dnsmasq[0].filter_aaaa=''1'' >/dev/null 2>&1 || true')
$installLines.Add('uci commit shadowsocksr >/dev/null 2>&1 || true')
$installLines.Add('uci commit network >/dev/null 2>&1 || true')
$installLines.Add('uci commit dhcp >/dev/null 2>&1 || true')
$installLines.Add('killall -q -9 ssr-switch >/dev/null 2>&1 || true')
$installLines.Add('rm -f /var/lock/ssr-switch.lock >/dev/null 2>&1 || true')
$installLines.Add('# Free memory before service restarts to prevent OOM')
$installLines.Add('sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true')
$installLines.Add('sleep 1')
$installLines.Add('rm -f /tmp/luci-indexcache')
$installLines.Add('rm -rf /tmp/luci-modulecache/* 2>/dev/null || true')
$installLines.Add('/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true')
$installLines.Add('sleep 2')
$installLines.Add('/etc/init.d/uhttpd restart >/dev/null 2>&1 || true')
$installLines.Add('# Reload cron so /etc/cron.d/ssrplus-persistence-check is picked up')
$installLines.Add('/etc/init.d/cron reload >/dev/null 2>&1 || /etc/init.d/cron restart >/dev/null 2>&1 || true')
$installLines.Add('# One-shot: wipe corrupt persistence file right now if present (TCP chain missing)')
$installLines.Add('if [ -f /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft ] && ! grep -q ss_spec_wan_fw_tcp /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft; then')
$installLines.Add('  rm -f /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft')
$installLines.Add('  log "wiped corrupt persistence file (no TCP chain) — next ssr-rules run will regenerate"')
$installLines.Add('fi')
$installLines.Add('# Cleanup leftover ssrplus-enhanced-* dirs from previous installer runs')
$installLines.Add('# (pre-v4 had `exec ./install.sh` which bypassed the EXIT trap, leaving 53MB+ per install)')
$installLines.Add('TMPROOT=${TMPDIR:=/tmp}')
$installLines.Add('CURRENT_PKG_DIR="$(CDPATH= cd -- "$PKG_DIR" && pwd)"')
$installLines.Add('for d in "$TMPROOT"/ssrplus-enhanced-*; do')
$installLines.Add('  [ -d "$d" ] || continue')
$installLines.Add('  case "$d" in "$CURRENT_PKG_DIR") continue ;; esac')
$installLines.Add('  rm -rf "$d" 2>/dev/null || true')
$installLines.Add('done')
$installLines.Add('rm -f "$TMPROOT/ssrp_enhanced.run" 2>/dev/null || true')
$installLines.Add('log "Install finished"')
$installLines.Add('log "Backup dir: $BACKUP_DIR"')
$installLines.Add('log "TXT import path: /root/ssrplus-txt"')
$installLines.Add('exit 0')

Write-Utf8NoBom (Join-Path $packageRoot 'install.sh') (($installLines -join "`n") + "`n")

Write-Host "[3/5] Creating full payload archive..."
$tarProc = Start-Process -FilePath 'tar.exe' -ArgumentList @('-czf', $tarballPath, '-C', $packageRoot, '.') -NoNewWindow -Wait -PassThru
if ($tarProc.ExitCode -ne 0) {
    throw "tar.exe failed with exit code $($tarProc.ExitCode)"
}

Write-Host "[4/5] Building self-extracting .run..."
$stubLines = New-Object System.Collections.Generic.List[string]
$stubLines.Add('#!/bin/sh')
$stubLines.Add('set -eu')
$stubLines.Add('')
$stubLines.Add('label="SSR Plus+ Enhanced Full Installer"')
$stubLines.Add('TMPROOT=${TMPDIR:=/tmp}')
$stubLines.Add('WORKDIR="$TMPROOT/ssrplus-enhanced-$$"')
$stubLines.Add('cleanup() {')
$stubLines.Add('  rm -rf "$WORKDIR"')
$stubLines.Add('}')
$stubLines.Add('trap cleanup EXIT INT TERM')
$stubLines.Add('mkdir -p "$WORKDIR"')
$stubLines.Add('echo "[SSRPLUS-INSTALL] Extracting package..."')
$stubLines.Add('tail -n +__SKIP__ "$0" | tar xzf - -C "$WORKDIR"')
$stubLines.Add('chmod +x "$WORKDIR/install.sh" "$WORKDIR/install.upstream.sh"')
$stubLines.Add('cd "$WORKDIR"')
$stubLines.Add('# Run install.sh as a child (NOT exec) so the EXIT trap below fires and cleans up WORKDIR.')
$stubLines.Add('# Pre-v4 used `exec ./install.sh` which replaced this shell process,')
$stubLines.Add('# bypassing the trap and leaving /tmp/ssrplus-enhanced-* (~53MB each) forever.')
$stubLines.Add('rc=0')
$stubLines.Add('./install.sh "$@" || rc=$?')
$stubLines.Add('cd /')
$stubLines.Add('exit $rc')
$stubLines.Add('__ARCHIVE_BELOW__')

$skip = $stubLines.Count + 1
$stubContent = (($stubLines -join "`n") + "`n").Replace('__SKIP__', [string]$skip)
$stubBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($stubContent)
$tarBytes = [System.IO.File]::ReadAllBytes($tarballPath)
$combined = New-Object byte[] ($stubBytes.Length + $tarBytes.Length)
[Array]::Copy($stubBytes, 0, $combined, 0, $stubBytes.Length)
[Array]::Copy($tarBytes, 0, $combined, $stubBytes.Length, $tarBytes.Length)
[System.IO.File]::WriteAllBytes($installerPath, $combined)

Write-Host "[5/5] Writing release metadata..."
$hash = (Get-FileHash -Algorithm SHA256 $installerPath).Hash.ToLowerInvariant()
Write-Utf8NoBom $shaPath "$hash  $([System.IO.Path]::GetFileName($installerPath))`n"

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$readme = @"
# SSR Plus+ Enhanced Full Installer

- Version: $Version
- Base release: $BaseRelease
- Architecture tag: $Arch
- Upstream full package: $(Split-Path -Leaf $UpstreamRunPath)
- Build time: $stamp
- Installer: $([System.IO.Path]::GetFileName($installerPath))

## Install

1. Download the `.run` file from this release.
2. Upload it to the router.
3. Run:

```sh
sh $([System.IO.Path]::GetFileName($installerPath))
```

## Package shape

- Full upstream payload is preserved (`depends/` + upstream `luci-app-ssr-plus` package)
- Enhanced files are applied as an overlay after the upstream install finishes
- Suitable for GitHub Releases and direct upload/install in iStore-like workflows

## Included enhancements

- SSR Plus+ controller / client / server node UI enhancements
- async apply with status feedback
- direct public IP vs proxied exit IP display
- node IP cache refresh and sync-apply fixes
- `ssr-rules` server-signature rebuild fix
- controlled auto switch with checked-node rotation and Google probe threshold
- batch `ss://` txt import
- Windows Clash recovery script export
- IPv6 strategy switch (off / auto / manual) with safe default `off`
- IPv6 disabled and AAAA filter enabled on install

## Notes

This package does not include any device-specific desktop bypass mode. It is safe to install behind downstream routers without per-PC assumptions.
"@
Write-Utf8NoBom $readmePath ($readme + "`n")

if (Test-Path $stageRoot) {
    Remove-Item -Recurse -Force $stageRoot
}

Write-Output "Built full package: $installerPath"
Write-Output "SHA256: $hash"
Write-Output "Size(bytes): $((Get-Item $installerPath).Length)"
Write-Output "Release dir: $releaseDir"
