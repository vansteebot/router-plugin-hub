# SSR Plus+ Enhanced — 20260512

## 修复

### 持久化文件半残导致 TCP 透明代理完全失效（关键修复）

**症状**：切换节点后所有节点都无效；状态页显示「代理出口 IP」是一个国内 IP；点「彻底清理并重启」按钮陷入「运行中 / 停止中」循环并提示「后台生效任务正在运行，按钮已锁定」；从路由器本机 `curl https://api.ip.sb/ip` 返回的是 WAN 直连 IP 而不是节点出口。表象很像 DNS 污染或机场出问题，但实际两者均健康。

**根因**：`/usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft` 这个持久化文件在某次写入过程中只保存了 UDP TPROXY 链，**`ss_spec_wan_fw_tcp` 链丢失**。`ssr-rules` 启动逻辑里有「server signature 未变化则直接从持久化文件恢复」的快速路径——这条路径每次都把残缺文件原样恢复，TCP REDIRECT 永远建不起来，导致所有 LAN TCP 流量直连出 WAN（UDP 仍走代理，所以 DNS 看起来正常，迷惑性极强）。

**修复**：
- **`ssr-rules.remote.sh` / `restore_from_persistence()`**：恢复前 grep 校验 `ss_spec_wan_fw_tcp`，缺失则视为损坏 — 删掉文件并返回失败，让上层调用回落到完整规则生成路径。标记 `AUTO-PATCH-TCP-VALIDATE`。
- **`ssrplus-persistence-check.cron`（新增）**：cron 守护，每 10 分钟兜底扫一次持久化文件;TCP 链缺失就清掉并写 syslog（`logger -t ssrplus-watchdog`）。即使 `ssr-rules` 路径意外被绕过,坏文件也躺不久。
- **安装脚本**：装包后立即执行一次"一次性体检",当场清掉残缺文件,然后 `/etc/init.d/cron reload` 让新 cron 立刻生效。

### 诊断信息

如果以后再遇到类似症状，按这个顺序排查就能 1 分钟内定位：

```sh
# 1. 看是不是同一个 bug
grep -q ss_spec_wan_fw_tcp /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft && echo "persistence OK" || echo "persistence CORRUPT"

# 2. 看实际 nft 是否有 TCP REDIRECT
nft list table ip ss_spec_mangle 2>&1 | grep -E 'tcp|redirect|tproxy'

# 3. 看真实代理出口
curl -s --max-time 8 https://api.ip.sb/ip   # 应为节点所在地区 IP, 不应为本机 WAN
```

## 安装包（完整合并包）

- 使用 **`build-full-package-from-upstream.ps1`** 生成（含上游 ipk + 本仓库增强层 + TCP 持久化校验 + cron 守护），体积约 **52MB**。
- 文件名：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260512.run`
- 构建目录：`packages/ssrplus-enhanced/release/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260512/`
- SHA256：`20f5ab69030eacadddec650015674c4773f386a062d8baa3056bee8756b45517`（同目录 `SHA256SUMS.txt`）。
- 已替代上一版 `ssrplus-enhanced-20260511`（该 release 已删除），本完整包包含其全部修复并叠加本次 TCP 持久化文件修复。

## 验证

打完包安装到路由器后，可以做以下验证：

```sh
# 1. 校验补丁是否在
grep "AUTO-PATCH-TCP-VALIDATE" /usr/bin/ssr-rules && echo PATCHED || echo NOT_PATCHED

# 2. cron 守护是否在
cat /etc/cron.d/ssrplus-persistence-check

# 3. 手动制造一个坏文件，看脚本是否会自愈
cp /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft /tmp/good.nft
grep -v 'ss_spec_wan_fw_tcp\|wan_fw_tcp\|tcp dport' /tmp/good.nft > /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft
/etc/init.d/shadowsocksr restart
# 等几秒后再查 — 坏文件应被清掉并重新生成
grep -c ss_spec_wan_fw_tcp /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft   # 应 >= 1
```
