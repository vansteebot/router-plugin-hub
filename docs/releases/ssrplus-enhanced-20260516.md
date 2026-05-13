# SSR Plus+ Enhanced — 20260516

## 修复:状态页 "chinadns-ng 未启动" 误报

### 症状

切节点 / 保存并应用 / 清理 DNS 缓存 之后,状态页持久显示红色错误:

> chinadns-ng 未启动,且未检测到 chinadns-ng/dns2socks 等 DNS 组件(请检查 SSR DNS 解析方式或依赖是否安装)

但实际**整个代理链路工作正常**,Google/YouTube/Claude/国内站点全部能开,只是 UI 状态卡在错误信息上。

### 三个独立 bug 叠加

1. **`wait_for_processes` 给 chinadns-ng 的等待时间只有 45 秒**,但实际上 SSR restart 之后 chinadns-ng 偶尔需要 50-70 秒才完全就绪(尤其在 dns-flush 之后被守护进程拉起的场景)。45 秒不够,sync-apply 报 dns error 退出。

2. **`should_retry` 列表里没有 `dns_flush`**,新加的 dns_flush reason 失败后**不会自动 hard_rebuild 重试**,卡在错误状态。

3. **`build_status_info` 不会清除 stale 错误**,即使后来 chinadns-ng 实际起来了,status 文件里的 `phase=dns` + 错误 message 一直被 UI 读出来,永远显示红色。

### 修复

- **`sync-apply.lua`** `wait_for_processes` 等待窗口 **45s → 75s**,留出 chinadns 监督进程拉起的余量
- **`sync-apply.lua`** `should_retry` 列表加入 `"dns_flush"`,失败后会自动走 `hard_rebuild` 强制完整重启
- **`shadowsocksr.lua`** `build_status_info` 增加自愈逻辑:`proxy 在跑 + chinadns/dns2socks/dns2tcp/mosdns/dnsproxy 任一在跑` → 清除 stale `phase=dns/process` 错误,phase 改为 `done`,标记 ok,触发出口 IP 重新检测

### 保留的修复(全部继承)

- 20260515:精准 DNS 分流 + cron 守护 `domestic_dns_servers` set
- 20260514:dnsmasq 自循环修复 + 「清理 DNS 缓存并生效」按钮 + 默认白名单补齐
- 20260513:chinadns-ng trusted upstream 默认 TCP(防 GFW UDP 投毒)
- 20260512:ssr-rules 持久化文件 TCP 链校验 + cron 守护

## 注意 — 关于 ChatGPT 卡顿

ChatGPT(chat.openai.com / chatgpt.com)在某些 SSR 节点上返回 403 或 卡顿,**和 DNS / 分流 无关**:DNS 已正确解析到 Cloudflare 真实 IP(172.64.x / 104.18.x),代理链路也通。这是 **OpenAI/Cloudflare 把当前节点 IP 标记为 VPN/abuse**(尤其是 HK PCCW 段、共享 IP 的 US 节点)。解决:换 ChatGPT 友好的节点(JP / 独立 IP 的 US)。

## 安装

```bash
# 路由器侧从 GitHub 拉取(经过现有代理出去,几十秒)
curl -L -o /tmp/ssrp_full.run https://github.com/vansteebot/router-plugin-hub/releases/download/ssrplus-enhanced-20260516/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260516.run
sh /tmp/ssrp_full.run
```

装完无需做任何界面操作。
