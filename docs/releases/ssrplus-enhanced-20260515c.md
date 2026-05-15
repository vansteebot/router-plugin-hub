# SSR Plus+ Enhanced — v20260515c

> 修两条让分流"用着用着就坏"的核心 bug,加一个根治 CRLF 的 git 配置。

| 项目 | 内容 |
|------|------|
| 版本 | **v20260515c** |
| 包类型 | full(含上游 ipk + depends) |
| 体积 | 54.4 MB |
| SHA256 | `072d4f9f150c5c1e9401717a1937ce57d090d9f5c5a944281d744a91a67edfd6` |
| 文件名 | `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515c.run` |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| Release | <https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260515c> |

---

## 🎯 修复 1 — `@china` nftset 静默截断

**症状**:启用"绕过大陆 IP"模式一段时间后(几小时到几天),**所有流量都被代理出去**,
包括百度、QQ、B 站这种本应直连的国内站点。重启 ssr 服务会暂时缓解,但很快复发。

**根因**:`ssr-rules` 早期实现用单条 `nft add element inet ss_spec china { ip1, ip2, …, ipN }`
一次性写入几万条国内 CIDR。这条命令在路由器上(`ipq53xx` / aarch64 / nftables 1.0.x)经常被
**内核静默截断**:命令 exit 0,但 set 里只存了几百条甚至零条。`grep` nft 日志看不到错误。

**后果**:nftables `ss_spec_wan_ac_tcp` 链最后一行是 `jump ss_spec_wan_fw_tcp`(走代理)。
当 `@china` 为空时,上一条 `ip daddr @china return` 永远不命中 → **所有流量都落入末位代理规则**。
路由器看不到任何 error,只有用户感觉"网慢了"。

**修复**:`ssr-rules.remote.sh` 新增 `nft_load_china_set` 函数:

- 流式按行读 `/etc/ssrplus/china_ssr.txt`(4181 行)
- 每 500 条 flush 一批 `nft add element ... { ... }`
- 最后通过 `nft get element inet ss_spec china { 1.0.0.0 }` 或 `{ 223.5.5.5 }`
  验证至少一个锚点 IP 真的进了 set
- 任意一批失败立即记 `loger 4` 警告;锚点验证失败记 `loger 3` 严重错误

替换原来的 `nft add element { $(tr '\n' ',' < ...) }` 一把梭写法。

---

## 🎯 修复 2 — `chinadns_forward` UCI 神秘清空 + 直通 WAN 兜底

**症状**:LuCI 上"清理 DNS 缓存并生效"按钮按完后,卡在 `queued` 状态不动;同时 LAN 客户端
拿到 GFW 污染的 Google IP(变成 Facebook IP `31.13.x` 之类),国内站点拿到海外 CDN IP。

**根因**:`shadowsocksr.init.remote.sh` 中 `start_dns()` 里:

```sh
local chinadns="$(uci_get_by_type global chinadns_forward)"
if [ -n "$chinadns" ]; then
    # 启动 chinadns-ng 监听 5333,作为 dnsmasq 上游
else
    # 直通模式:dnsmasq 改用 WAN DNS 当上游
fi
```

LuCI sync-apply 在某些路径下(疑似 dns-flush + rebuild 串行执行)会**清掉**
`shadowsocksr.@global[0].chinadns_forward` 这个 UCI 值。下次 init.d 启动时
`uci_get_by_type` 返回空字符串 → 走 else → dnsmasq 上游变成 `112.4.0.55`(运营商 DNS)
→ 国外域名被 GFW 污染,国内域名被运营商 GeoDNS 路由到海外 CDN。

**修复**:`uci_get_by_type` 加 fallback 默认值 `223.5.5.5:53`(AliDNS):

```sh
local chinadns="$(uci_get_by_type global chinadns_forward 223.5.5.5:53)"
```

两处 lookup(单 server inject + router-mode start_dns)都加。UCI 真为空时仍能保证
chinadns-ng 启动,分流逻辑保持完整。用户要"真正禁用 chinadns"应该用 magic value
(`wan` 或 `wan_114`),而不是清空字段。

---

## 🛡 修复 3 — `.gitattributes` 根治 CRLF

**症状**:从 GitHub clone 代码 → build .run → 装到路由器,装完发现:

- `/etc/init.d/shadowsocksr restart` 报 `/usr/bin/ssr-rules: not found`
- LuCI 进 ShadowSocksR Plus+ 页面 500: `Syntax error in status.htm:1: unfinished string near "'"`

**根因**:Windows git 默认 `core.autocrlf=true`,checkout 时把所有 text 文件 LF 换成 CRLF。
build-release-package.ps1 直接打包工作区里的文件,把 CRLF 带进了 tar.gz,再被 makeself 装到
Linux 路由器。Linux shell 看到 `#!/bin/sh\r` 当成解释器路径,显然不存在 → "not found";
LuCI Lua 模板解析器看到 `<%...\r%>` 中 `\r` 异常 → unfinished string。

**修复**:新增 `.gitattributes`,精确控制每类文件的 EOL:

| Pattern | EOL |
|---------|-----|
| `*.sh` `*.init` `*.lua` `*.htm` `*.html` `*.conf` `*.cron` `*.list` `*.txt` `*.json` `*.yaml` `*.yml` `*.md` | **LF**(部署到路由器) |
| `*.ps1` `*.cmd` `*.bat` | **CRLF**(Windows 原生) |
| `*.run` `*.tar` `*.tar.gz` `*.tgz` `*.gz` `*.zip` `*.7z` `*.png` `*.jpg` `*.jpeg` `*.gif` `*.ico` `*.pdf` | **binary**(不规范化) |

下次 clone 时这些文件无论 git config 如何都会按规则 checkout,build 出来的 .run 就是干净的 LF。

---

## 🧹 次要清理 — 删除 `chinadns-ng -f`

chinadns-ng 2024+ 版本的 help 输出:

```
-f, --fair-mode  enable fair mode (nop, only fair mode now)
```

`-f` 已经是 nop。保留只是噪音,容易让人误以为关掉/打开能改变行为。

---

## 📦 安装

### SSH 上传 + 命令行
```bash
scp ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515c.run root@192.168.8.1:/tmp/
ssh root@192.168.8.1 'sh /tmp/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515c.run && /etc/init.d/shadowsocksr restart'
```

### iStore Web 上传
1. 从 [Release 页面](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260515c) 下载 .run
2. iStore → 手动上传 → 选 .run → 安装
3. 完成后 LuCI → 服务 → ShadowSocksR Plus+ → 重新生效网络

安装过程会把当前 `/etc/ssrplus/` `/usr/share/shadowsocksr/` `/usr/bin/ssr-*` `/etc/init.d/shadowsocksr` 等
打包到 `/root/ssrplus-enhanced-install-backup-<时间戳>/`,出错可手动回滚。

---

## ✅ 验证(装完在路由器 SSH 执行)

```bash
# 1. daemon 全部在跑
ps w | grep -E 'chinadns|ss-redir|ssr-rules|ssr-monitor' | grep -v grep | wc -l   # 期望 4 或 5

# 2. @china set 真的有内容
nft list set inet ss_spec china | grep -oE '([0-9]+\.){3}[0-9]+' | wc -l           # 期望 ≥ 3000

# 3. 国内 IP 命中 china set(随便挑一个国内段抽样)
nft get element inet ss_spec china '{ 223.5.5.5 }'                                  # 不报错 = 命中

# 4. chinadns_forward 有值
uci -q get shadowsocksr.@global[0].chinadns_forward                                  # 期望 223.5.5.5:53 或别的

# 5. 端到端
curl -s -m 5 -o /dev/null -w 'baidu  %{http_code} via %{remote_ip}\n' https://www.baidu.com
curl -s -m 8 -o /dev/null -w 'google %{http_code} via %{remote_ip}\n' https://www.google.com
```

baidu 应该 200 且 `remote_ip` 落在国内段(`36.x` / `183.x` / `223.x` 等),
google 应该 302 且 `remote_ip` 落在 Google 真实段(`142.250.x` / `142.251.x`)。

---

## ⚠️ 已知遗留(未在本次修复)

**`chinadns-ng -4 china` 用的是旧 ipset 语法**,新版本 chinadns-ng (2025.08+) 看到没 `@` 的
setname 会去找 **ipset** 而不是 nftset。本路由器没有任何 ipset(只有 nftables),
chnroute 检查永远 fail → 所有 trusted DNS 答复(走代理出口的 1.1.1.1)都被采纳 →
**国内域名拿到海外 GeoDNS 答案**(baidu → `103.235.46.x` wshifen 海外镜像,qq → 腾讯云海外段等)。

完整修复需要:

1. 创建 `china6` nftset 并写入 ssr-rules 的 persistence 文件
2. chinadns-ng 启动参数改成 `-4 inet@ss_spec@china -6 inet@ss_spec@china6`
3. 改 `ssr-rules.remote.sh` 的 `ipset_nft()` 函数确保 `china6` 在 nftables restore
   之后也仍然存在

这套改动有非平凡的失败路径(本次会话试过一次,曾经让网络断 1 小时),
不适合"打游击"式上线,需要单独冷静设计。**追踪 issue 待补**。

---

## 📜 涉及 commit

- `9000431` fix(ssrplus-enhanced): chinadns_forward fallback + add .gitattributes (LF on router payloads)
- `5ed81ea` fix(ssrplus-enhanced): batched china set loader + direct-DNS-mode follow-up
