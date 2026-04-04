$ErrorActionPreference = 'SilentlyContinue'

Write-Host '[SSRPlus] Closing Windows system proxy residue...'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Type DWord -Value 0
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name AutoConfigURL -ErrorAction SilentlyContinue
netsh winhttp reset proxy | Out-Null

Write-Host '[SSRPlus] Flushing DNS cache...'
ipconfig /flushdns | Out-Null

Write-Host '[SSRPlus] Removing Clash tunnel routes...'
$routeTargets = Get-NetRoute -ErrorAction SilentlyContinue | Where-Object {
    $_.InterfaceAlias -match 'Clash|cfw-tap' -or
    $_.NextHop -eq '198.18.0.2' -or
    $_.DestinationPrefix -like '198.18.*'
}
foreach ($route in $routeTargets) {
    Remove-NetRoute -DestinationPrefix $route.DestinationPrefix -InterfaceIndex $route.InterfaceIndex -NextHop $route.NextHop -Confirm:$false -ErrorAction SilentlyContinue
}

$persistentTargets = Get-NetRoute -PolicyStore PersistentStore -ErrorAction SilentlyContinue | Where-Object {
    $_.InterfaceAlias -match 'Clash|cfw-tap' -or
    $_.NextHop -eq '198.18.0.2' -or
    $_.DestinationPrefix -like '198.18.*'
}
foreach ($route in $persistentTargets) {
    Remove-NetRoute -PolicyStore PersistentStore -DestinationPrefix $route.DestinationPrefix -InterfaceIndex $route.InterfaceIndex -NextHop $route.NextHop -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host '[SSRPlus] Resetting adapter DNS where possible...'
$upAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }
foreach ($adapter in $upAdapters) {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
}

Write-Host '[SSRPlus] Done. If the browser is still stale, disable/enable the active adapter once.'
