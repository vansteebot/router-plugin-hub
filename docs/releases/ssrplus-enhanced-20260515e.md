# SSR Plus+ Enhanced — v20260515e

> 终于让"严格分流"真正生效的版本。同一天 c → d → e 三次 build 的故事:c 引入 chnroute 修复但漏 china6 set,d 加 china6 但 loader 函数签名 bug 导致 `@china` 永远空,e 修了 loader,验证从 cold boot 一路通到 google.com。

| 项目 | 内容 |
|------|------|
| 版本 | **v20260515e** |
| 包类型 | full(含上游 ipk + depends) |
| 体积 | 54.4 MB |
| SHA256 | `fc8b6abedba0c13984c428501aaee5e830bbdc895c795699916dd9fa751462d1` |
| 文件名 | `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run` |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| Release | <https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260515e> |

---

## 🎯 修复 1 — `nft_load_china_set` 参数解析(关键 bug,c/d 都没修)

**症状**:

- LuCI 上"中国大陆 IP 段数据库"显示 `新的总记录数: 4183`(看起来正常下载更新)
- 但 SSH 进路由器查:`nft list set inet ss_spec china | wc -l` 是 **0** 或者只剩旧的 3585(残留)
- 任何 ssr-rules force rebuild 之后,`@china` 都会变空
- 表现:绕过大陆 IP 模式下,所有 TCP/UDP 都进末位代理规则,百度/QQ/B 站经海外节点出去,3 秒起步

**根因**(`5ed81ea` 引入,c/d 没察觉):

```sh
# 函数签名(错):
nft_load_china_set() {
    local table="$1"                          # "inet"
    local setname="$2"                        # "ss_spec"
    local china_file="${3:-/etc/ssrplus/china_ssr.txt}"  # "china"  ← bug
}

# 调用站(两处,都传 4 个位置参数):
nft_load_china_set inet ss_spec china "$china_ip"
```

`china_file` 拿到的是字符串 `"china"`,`[ -f china ]` false → 早返回 `loger 3 "china route file missing: china"`。
但日志看到 `china set loaded` 是 daemon 后续 `Memory rules flushed successfully` / `NFTables rules
applied successfully` 写的,跟 loader 实际是否成功无关 —— 所以这个 bug 在生产路由器上**隐藏了好几个版本**,
只是因为旧版本的 nftables persistence 文件(2026-05-08 那次正常 build 写的)一直还在,
ssr-rules 每次启动都 restore 那个 3585 条的副本进来,loader 失败也没人发现。

直到 v515c 改 chnroute 让我们删了 persistence 文件,空 `@china` 立刻暴露。

**修复**(`7a44517`):函数加 `family` 第一参数:

```sh
nft_load_china_set <family> <table> <setname> [file]
```

- $1 = family (inet / ip)
- $2 = table (ss_spec / ss_spec_mangle)
- $3 = setname (china)
- $4 = file (/etc/ssrplus/china_ssr.txt)

内部所有 `nft add/get element` 都改用 `$family $table $setname` 三段位置参数。
调用站已经天然传 4 个 token,无须改动。

---

## 🎯 修复 2 — chinadns-ng chnroute 终于真正生效

**症状**:DNS 解析国内站点(`nslookup www.baidu.com 127.0.0.1:5333`)返回 `103.235.46.102`(wshifen 海外镜像),
`www.qq.com` 返回 `43.175.144.123`(腾讯云海外),b 站 / 淘宝 / 京东 / 虎牙类似。

**根因**:`-4 china` 是 chinadns-ng 旧版的 ipset 语法。新版(2025.08.09)的 `--help`:

```
-4, --ipset-name4 <set4>  ip test for tag:none, default: chnroute
                          if setname contains @, then use nftset
                          format: family_name@table_name@set_name
```

没 `@` → 找 ipset。本路由器(OpenWrt 23.05-SNAPSHOT + ipq53xx)只有 nftables,
没 ipset → chnroute 检查永远 fail → 所有 chnlist (223.5.5.5) 答复都被当作"不可信",
trusted (走代理出口的 1.1.1.1,加拿大 GeoDNS) 答复总是胜出 → 拿到海外答案。

**修复**(`5b62008`):chinadns-ng 启动参数改用 nftset 路径:

```
chinadns-ng -l $china_dns_port -4 inet@ss_spec@china -6 inet@ss_spec@china6 \
            -p 3 -c ${chinadns/:/#} -t 127.0.0.1#$dns_port -N -r
```

---

## 🎯 修复 3 — `china6` IPv6 nftset 持久化

**症状**:把 `-4` 改成 nftset 路径之后,chinadns-ng 启动直接退出:

```
parse_name_nftset: invalid family: 'chnroute6'
```

**根因**:chinadns-ng 看到 `-4` 用 nftset 模式(setname 含 `@`),会**强制把 `-6` 默认值
`chnroute6` 也按 nftset 解析**。`chnroute6` 没 `@` → `parse_name_nftset` 报错退出。

第一次试这个修复时,我手动 `nft add set inet ss_spec china6 ...` 创建,
chinadns 起来了 —— 但 ssr-rules 下次 restart 时,**ssr-rules 的 ipset_nft() 函数
没把 china6 列在 set 创建循环里**,导致 force rebuild 时 china6 不会被建,
chinadns 又起不来。

**修复**(`5b62008`):在 `ssr-rules.remote.sh` 的 `ipset_nft()` 里,
在主 `china` (ipv4_addr) set 旁,**强制创建一个空的 `china6` (ipv6_addr)**:

```sh
# IPv6 chnroute set: kept empty on purpose (IPv6 is disabled at the proxy
# layer here) but MUST exist so chinadns-ng can be launched with
# `-6 inet@ss_spec@china6`. ... The daemon's persistence exporter walks
# the entire `inet ss_spec` table, so an empty china6 set also survives
# across `ssr-rules restore`.
if ! $NFT list set inet ss_spec china6 >/dev/null 2>&1; then
    $NFT add set inet ss_spec china6 '{ type ipv6_addr; flags interval; auto-merge; }' 2>/dev/null
fi
```

ssr-rules daemon 的 persistence exporter 自动把整个 `inet ss_spec` 表 export 进
`/usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft`,所以 china6 set
即使重启之后被 restore 也仍然存在。

---

## 🛡 沿用 v515c 的修复

- `@china` nftset 分批加载(`nft_load_china_set` 500 条一批)
- `chinadns_forward` UCI 兜底 AliDNS(`223.5.5.5:53`)
- `.gitattributes` 根治 CRLF
- 删除 chinadns-ng `-f`(2024+ 是 nop)

---

## 📦 安装

### SSH 上传 + 命令行(推荐)

```bash
scp ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run root@192.168.8.1:/tmp/
ssh root@192.168.8.1 'sh /tmp/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run'
# 关键:删旧 persistence 文件,否则会 restore 上一版的空 @china
ssh root@192.168.8.1 'rm -f /usr/share/nftables.d/ruleset-post/99-shadowsocksr.nft'
ssh root@192.168.8.1 'reboot'
```

**`reboot` 是建议步骤** —— 重启可以确保 ssr-rules / chinadns-ng / nftables 从干净状态加载,
避免上次会话累积的 chain truncation 状态。如果不想重启,
可以 `/etc/init.d/shadowsocksr stop && sleep 3 && /etc/init.d/shadowsocksr start`
然后验证 `nft list chain inet ss_spec ss_spec_wan_ac_tcp | tail -3` 末位有 `jump ss_spec_wan_fw_tcp`。

### iStore Web 上传
1. 从 [Release](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260515e) 下载 .run
2. iStore → 手动上传 → 选 .run → 安装
3. 完成后 LuCI → 服务 → ShadowSocksR Plus+ → 重新生效网络
4. (推荐)在路由器 SSH 跑 `reboot`

---

## ✅ 实测验证(GL-BE3600,cold boot 后)

```
$ uptime
 22:08:10 up 2 min,  load average: 2.18, 1.25, 0.50

$ nft list set inet ss_spec china | grep -oE '([0-9]+\.){3}[0-9]+' | wc -l
3589
$ nft list set inet ss_spec china6 | head -3
table inet ss_spec {
    set china6 {
        type ipv6_addr

$ nft list chain inet ss_spec ss_spec_wan_ac_tcp | tail -4
        ip daddr @china return
        ip saddr @gmlan ip daddr != @china jump ss_spec_wan_fw_tcp
        jump ss_spec_wan_fw_tcp
    }
```

DNS 解析 + 路由决策:

| 域名 | 解析 IP | 路由 | curl 状态 |
|---|---|---|---|
| www.baidu.com | 36.152.44.93 (国内) | IN_CHINA 直连 | 200 in 3.17s |
| www.qq.com | 183.194.238.19 (国内) | IN_CHINA 直连 | 501 in 0.29s |
| www.bilibili.com | 112.13.92.203 (国内) | IN_CHINA 直连 | 200 in 3.76s |
| www.taobao.com | 36.150.233.13 (国内) | IN_CHINA 直连 | 200 in 1.38s |
| www.jd.com | 36.150.39.3 (国内) | IN_CHINA 直连 | 200 in 0.50s |
| www.huya.com | 36.151.20.202 (国内) | IN_CHINA 直连 | 200 in 0.36s |
| www.google.com | 142.251.157.119 | 代理 | 302 in 4.06s |
| www.youtube.com | 142.250.139.93 | 代理 | 200 in 5.21s |
| chatgpt.com | 104.18.32.47 | 代理 | 403 in 2.06s |
| github.com | 140.82.114.4 | 代理 | 200 in 2.60s |

国内全部走 `@china return` 直连国内 CDN,国外全部 `jump ss_spec_wan_fw_tcp` → 1234 → ss-redir → 加拿大节点。
彻底告别"用着用着国内站越来越慢"。

---

## 📜 涉及 commit

- `7a44517` fix(ssrplus-enhanced): nft_load_china_set arg parsing — setname was being read as the file path
- `5b62008` fix(ssrplus-enhanced): chinadns chnroute via nftset path + china6 persistence
- `1a0d48b` docs: point README at v20260515c
- `9000431` fix(ssrplus-enhanced): chinadns_forward fallback + add .gitattributes
- `5ed81ea` fix(ssrplus-enhanced): batched china set loader + direct-DNS-mode follow-up
