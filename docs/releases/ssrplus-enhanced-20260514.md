# SSR Plus+ Enhanced — 20260514

## 关键修复 — 切境外节点后国内站点被解析到境外 CDN 并被长期缓存

### 症状

切到 HK/US/JP 等境外节点后,**国内网站(百度/淘宝/QQ/支付宝/B站等)打开慢、卡、加载错位**。表象是网"还在",但国内站全部很慢。直接查 `nslookup www.baidu.com 127.0.0.1` 会返回 `103.235.46.x`(百度海外 CDN)而不是 `36.152.44.x`(国内联通)。**切回境内节点 / 重启 SSR 都无济于事**——错的 IP 一直被服务,要等大约一天才自动失效。

### 根因(双重 bug)

1. **`gfw2ipset.sh` 生成的 `whitelist_forward.conf` 用 `server=/baidu.com/127.0.0.1`(没指定端口)** —— 127.0.0.1:53 就是 dnsmasq 自己,形成转发回环。dnsmasq 检测到回环后 fallback 到主转发链 → 走 chinadns-ng:5333,**完全没起到白名单的隔离作用**。
2. **chinadns-ng `cache-stale=86400`(1 天)缓存** —— 当代理出口是境外节点时,chinadns-ng 通过 `-c 223.5.5.5` 查阿里 DNS 的请求实际从代理出去(本机出站 OUTPUT 链也被 ss-redir 影响),阿里 DNS 看到的查询源 IP 是境外,**根据 GeoDNS 返回百度的海外 CDN IP**(103.235.46.x 香港)。这个错 IP 进入 chinadns-ng 内存缓存,即使后来切回境内节点,**缓存 1 天不刷新**,所有 LAN 设备都拿到错的 IP。

### 修复

#### A. 白名单走真正的国内 DNS(不走 chinadns)— 永久修复

- **`gfw2ipset.remote.sh`**:`whitelist_forward.conf` 生成时,DNS 后端从 `127.0.0.1`(死循环) 改成 `$(uci get chinadns_forward)` 的国内 DNS IP(默认 `223.5.5.5`)。这样 baidu/qq/taobao 等域名的解析**直接从路由器 WAN 出去到阿里 DNS**,不经过任何代理 NAT,阿里 DNS 看到的源 IP 永远是国内运营商,永远返回正确的国内 CDN IP。
- **安装脚本**:补齐缺失的白名单域名(taobao.com、tbcache.com、tmall.com、alibaba.com、alicdn.com、aliyun.com、alipay.com、1688.com、mmstat.com、aliexpress.com、xiaohongshu.com、xhscdn.com、douyin.com、bytedance.com、bilibili.com、bilivideo.com)。

#### B. 新增「清理 DNS 缓存并生效」按钮 — 应急自助

状态页工具栏新增一个按钮(在「重新生效网络」和「彻底清理并重启」之间)。点击后:

1. 删 chinadns-ng 可能存在的持久化缓存文件
2. kill 所有 chinadns-ng 进程(让内存缓存随进程死亡)
3. 重启 dnsmasq(清掉 dnsmasq 自己的 LRU 缓存)
4. 排队 sync-apply rebuild(让 SSR 把 chinadns-ng 重新拉起,启动时缓存全新)

实现:
- `dns-flush.sh`(新):路由器侧清缓存脚本,放 `/usr/share/shadowsocksr/dns-flush.sh`
- `shadowsocksr.lua`:新增 `flush_dns` 路由和 `act_flush_dns` action
- `status.htm`:新增 `清理 DNS 缓存并生效` 按钮 + hover 提示

### 包含上版修复

20260513 (chinadns-ng 默认 TCP 上游) 和 20260512 (TCP 持久化文件校验 + cron 守护) 的修复全部保留。

## 安装

```bash
scp ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260514.run root@192.168.8.1:/tmp/
ssh root@192.168.8.1 'sh /tmp/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260514.run'
```

## 验证

```sh
# 1. 白名单走阿里 DNS(不再写 127.0.0.1)
grep -E '^server=/baidu.com/' /tmp/dnsmasq.d/dnsmasq-ssrplus.d/whitelist_forward.conf
# 应输出: server=/baidu.com/223.5.5.5

# 2. dns-flush 脚本存在
test -x /usr/share/shadowsocksr/dns-flush.sh && echo DNS_FLUSH_OK

# 3. controller 有 flush_dns action
grep flush_dns /usr/lib/lua/luci/controller/shadowsocksr.lua

# 4. 国内站点解析到真实国内 IP(切到 US 节点也应该正常)
for d in www.baidu.com www.qq.com www.taobao.com www.alipay.com; do
    printf "%-25s " "$d"
    nslookup -type=A "$d" 127.0.0.1 2>/dev/null | awk '/^Address[: ]/ {a=$NF} END {print a}'
done
# 期待:36.x、183.x、223.109.x 等国内 IP,而不是 103.235.x、155.102.x 等境外 CDN
```

## 仍未解决

- `sync-apply.lua` 锁机制无 stale 超时,异常情况下按钮可能锁很久
- 状态页 phase 字段可能与 ip 字段不同步(早期 DNS 阶段失败的 message 不会被后续成功覆盖)
