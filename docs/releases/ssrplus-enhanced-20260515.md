# SSR Plus+ Enhanced — 20260515

## 关键修复 — 架构级精准 DNS 分流(不再依赖域名白名单)

### 用户反馈的根本问题

20260514 通过把 `whitelist_forward.conf` 里的 baidu/qq/taobao 等域名指向 `223.5.5.5` 来绕过 chinadns-ng 缓存污染——这只是**修复了具体几个域名**,但任何不在白名单里的国内站点(sina.com、网易、知乎、CSDN…)切到境外节点后依然会被解析到境外 CDN。**这是治标不治本**。

### 真正的根因

ChinaDNS-NG 的工作机制本来就是"国内域名走国内 DNS,境外域名走境外 DNS"——不需要白名单。**但有一个前提**:它发往国内 DNS 服务器(223.5.5.5)的查询包必须从路由器**直连 WAN** 出去,这样阿里/腾讯 DNS 看到的源 IP 是国内 ISP,GeoDNS 才会返回正确的国内 CDN。

之前的问题是:**chinadns-ng 发到 223.5.5.5 的 UDP/TCP 包被 ss-redir 拦截走代理了**。从境外节点出去时,阿里 DNS 看到的源 IP 是境外,GeoDNS 给出境外 CDN IP,chinadns-ng 收到这个"看似有效但其实是境外 CDN 的 IP",缓存它,**整个 LAN 都拿到错的 IP**。

### 修复(架构级)— `ssr-rules.remote.sh`

在 `inet ss_spec` table 里新增 nft set **`domestic_dns_servers`**,内置常见国内 DNS 服务器 IP:

```
223.5.5.5  223.6.6.6              # AliDNS
119.29.29.29  119.28.28.28        # Tencent DNSPod
180.76.76.76                      # Baidu DNS
114.114.114.114  114.114.115.115  # 114DNS
1.2.4.8  210.2.4.8                # CNNIC SDNS / DNSPod
117.50.10.10  117.50.11.11        # OneDNS
112.124.47.27  114.215.126.16     # Ali backup
```

同时**自动**从 uci 提取 `chinadns_forward` 和 `chinadns_ng_shunt_dnsserver` 用户配置的国内 DNS,自动加入此 set。

然后在 `ss_spec_wan_ac_tcp/udp` 和 `ss_spec_output_udp` 链最前面加 bypass 规则:

```
ip daddr @domestic_dns_servers (tcp|udp) dport 53 return
```

**这条规则覆盖三种流量路径**:
1. **LAN 设备直接查国内 DNS**(`PREROUTING → wan_ac_*`)— 直连出 WAN
2. **路由器自身 TCP 查询**(`OUTPUT TCP → wan_ac_tcp`)— 直连出 WAN
3. **路由器自身 UDP 查询**(`OUTPUT UDP → ss_spec_output_udp`)— 不打 TPROXY mark,走默认路由

### 为什么这是正确的架构修复

| 方面 | 白名单方式(20260514) | 精准分流(20260515) |
|---|---|---|
| 覆盖面 | 只覆盖列表里的域名 | **覆盖所有国内站点(任何域名)** |
| 维护成本 | 每个新国内站都要加 | **零维护** |
| 工作机制 | 强制路径,绕过 chinadns | **修好 chinadns,让其本来的分流逻辑工作** |
| chinadns 缓存 | 缓存可能存错 IP | **不会缓存错 IP** |
| GFW 抗性 | 不影响 | 不影响(GFW 信任上游已是 TCP) |

### 自检

装完后路由器跑:

```sh
# 1. nft set 存在且有 IP
nft list set inet ss_spec domestic_dns_servers | head

# 2. bypass 规则到位
nft list chain inet ss_spec ss_spec_wan_ac_udp | grep domestic_dns_servers
nft list chain inet ss_spec ss_spec_wan_ac_tcp | grep domestic_dns_servers
nft list chain inet ss_spec ss_spec_output_udp | grep domestic_dns_servers

# 3. 切到境外节点测试国内站点(任意域名,不必在任何列表里)
for d in www.sina.com.cn www.163.com www.zhihu.com www.csdn.net www.iqiyi.com www.youku.com www.jd.com www.meituan.com; do
    printf "%-25s " "$d"
    nslookup -type=A "$d" 127.0.0.1 2>/dev/null | awk '/^Address[: ]/ {a=$NF} END {print a}'
done
# 期待:全部是 36.x / 39.x / 42.x / 110.x / 119.x / 121.x / 124.x / 180.x / 183.x / 222.x / 223.x 等国内 IP
# 不应该出现:103.235.x(百度 HK CDN)、155.102.x(境外)、69.x(Facebook)等
```

### 保留的修复

- 20260514:`whitelist_forward.conf` 的 `127.0.0.1` 自循环 bug 修复(独立问题,跟分流架构无关,继续修)
- 20260514:white.list 域名补齐(只是修上游遗漏,跟分流架构无关)
- 20260514:DNS 缓存清理按钮(作为应急工具保留)
- 20260513:chinadns-ng trusted upstream 默认 TCP(防 GFW UDP 投毒)
- 20260512:`ssr-rules` 持久化文件 TCP 链校验 + cron 守护

## 安装

```bash
scp ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515.run root@192.168.8.1:/tmp/
ssh root@192.168.8.1 'sh /tmp/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515.run'
```

装完会自动 SSR 重启,旧的 chinadns-ng 缓存(可能含污染 IP)随进程死亡而清除,新启动的 chinadns-ng 走新的精准分流路径。
