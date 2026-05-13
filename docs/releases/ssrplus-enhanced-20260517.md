# SSR Plus+ Enhanced — 20260517

## 修复:状态页「直连公网 IP」显示成节点出口 IP

### 症状

切到境外节点之后,状态页显示的两个 IP **变成同一个**(都是节点出口 IP),`直连公网 IP` 不再是 WAN 真实 IP。表象像 "DNS 又失效了" / "两个 IP 反过来了",实际**网络完全正常**(Google/百度/Claude/ChatGPT 全部能开)。

### 根因

`get_direct_public_ip()` 用 `https://myip.ipip.net` / `https://ddns.oray.com/checkip` / `https://ip.3322.net` 这三个 echo IP 的服务来探测 WAN 真实 IP。

问题:这些服务的服务器**自身 IP 不在 chnroute 表里**(ipip.net 是国际公司),所以 SSR 把这些查询当成境外流量走代理出去——回来看到的 IP 是**节点出口 IP**,不是 WAN 真实 IP。

切到境外节点 → ipip.net 走代理 → 返回节点出口 IP → UI 显示「直连公网 = 节点 IP」(完全错的)。

### 修复

`get_direct_public_ip()` 优先**直接读 PPPoE 接口的 IPv4 地址**(`ifstatus wan` 的 `ipv4-address`):

```lua
for _, iface in ipairs({ "wan", "wwan" }) do
    local raw = exec("ifstatus " .. iface)
    if raw ~= "" then
        local parsed = jsonc.parse(raw)
        if parsed and parsed["ipv4-address"] then
            for _, entry in ipairs(parsed["ipv4-address"]) do
                if entry.address and not entry.address:match("^127%.") then
                    return entry.address
                end
            end
        end
    end
end
-- 上面读取不到才回退到 HTTP 探测
```

这是**绝对的 ground truth**:
- 永远是 WAN 真正分配的 IP
- 不受代理出口影响
- 不受 GeoDNS 影响
- 不需要发任何 HTTP 探测

两个文件都改:`sync-apply.lua`(后台同步逻辑)和 `shadowsocksr.lua`(LuCI 状态读取),保证两条路径都用同一个 ground truth。

### 保留的所有早期修复

- 20260516:状态页"chinadns-ng 未启动"误报自愈
- 20260515:精准 DNS 分流(`domestic_dns_servers` set,无需白名单)
- 20260514:dnsmasq 自循环修复 + DNS 缓存清理按钮
- 20260513:chinadns-ng 默认 TCP 上游
- 20260512:ssr-rules 持久化 TCP 链校验

## 安装

```bash
curl -L -o /tmp/ssrp_full.run https://github.com/vansteebot/router-plugin-hub/releases/download/ssrplus-enhanced-20260517/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260517.run
sh /tmp/ssrp_full.run
```
