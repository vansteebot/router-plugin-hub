# SSR Plus+ Enhanced — 20260518

## 修复:DNS 配置选错就全瘫 + 国内站被劫持 DNS 解析到错 IP

### 用户反馈

1. **"DNS 解析方式"选了"直通模式"后整个网络无法访问**
2. **国内 DNS 默认配置 `wan_114` 容易被劫持**(`114.114.114.114` 在国内 ISP 中被广泛劫持/投毒)
3. 切境外节点后国内站被解析到境外 CDN(虽然 20260515 修了核心路径,但默认配置下 chinadns 上游用 114DNS 仍然会拿到错 IP)

### 修复

#### A. 直通模式自愈(`shadowsocksr.init.remote.sh`)

当用户在 `run_mode=router` 或 `gfw` 下选 `pdnsd_enable=0`(直通模式禁用 ChinaDNS-NG)时,这种组合**必然导致境外站不可访问**(GFW 列表的 `server=/.../127.0.0.1#5335` 找不到监听端口,fallback 到 ISP DNS,被污染)。

修复:`start_dns()` 入口处检测这种"配置矛盾",**自动改写 uci 为 `pdnsd_enable=6` 并写 syslog 提示**。用户随便选都能用,避免"我选了直通然后什么都打不开"的陷阱。

#### B. 国内 DNS 默认从 `wan_114` 改成 AliDNS

`chinadns_forward` 空值的兜底:
- 之前:`wan_114` = `WAN下发的DNS,114.114.114.114` — 两者都不可靠
- 现在:`223.5.5.5:53` (AliDNS) — 国内权威解析,GeoDNS 对国内 IP 准确

旧的 `wan_114` 选项仍然存在(向后兼容),但**运行时自动替换为 `AliDNS + WAN DNS`**(WAN DNS 保留用于 LAN .local 解析)。

#### C. UI 选项重排 + 警告标注(`client.lua`)

"国内 DNS 服务器" 字段:
- AliDNS 移到第一,标 `[推荐]`,设为默认值
- `114DNS` / `WAN DNS` / `WAN+114` / `Disable ChinaDNS-NG` 全部标 `[不推荐]` 并加原因
- description 加详细说明

### 核心架构(回顾,自 20260515 起一直生效)

chinadns-ng 的 split-DNS 工作机制:
- `-c <国内DNS>` 并发 `-t tcp://1.1.1.1#53` (TCP 防 GFW 投毒)
- 比对 -c 答案的 IP:**至少一个在 chnroute → 用 -c 答案**(走直连),否则用 -t 答案(走代理)
- `-c` 查询走 `domestic_dns_servers` nft 集合 bypass(精准分流),永远从国内 ISP 出口

**当一个域名同时返回国内+境外 IP 时,只要至少一个国内 IP → 整套答案走国内直连。这就是"双答时偏好国内"的实现机制,**不需要白名单。**

### 保留的所有早期修复

- 20260517:`get_direct_public_ip()` 优先读 ifstatus(避免被代理污染显示)
- 20260516:状态页"chinadns-ng 未启动"误报自愈
- 20260515:精准 DNS 分流(`domestic_dns_servers` set)
- 20260514:dnsmasq 自循环修复 + DNS 缓存清理按钮
- 20260513:chinadns-ng 默认 TCP 上游
- 20260512:ssr-rules 持久化文件 TCP 链校验

## 安装

```bash
curl -L -o /tmp/ssrp_full.run https://github.com/vansteebot/router-plugin-hub/releases/download/ssrplus-enhanced-20260518/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260518.run
sh /tmp/ssrp_full.run
```
