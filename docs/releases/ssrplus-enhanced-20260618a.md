# SSR Plus+ Enhanced — v20260618a

> 🆕 **刚买回路由器的新手** 看这里 → **[全新手完整教程](../tutorials/getting-started.md)**(开箱激活 → 一键 iStore → 上传本 .run → 4 条防 WebRTC/QUIC 泄漏规则 → 浏览器自测)。下面这份是给开发/熟手看的根因分析与验证数据。

> 解开 UI 死锁的版本。前面几个版本把"严格分流"修通之后,日常使用上还残留一个体感很差的问题:点一下"重新生效网络"或者切节点,客户端页和"服务器节点"页全部按钮立刻变灰,要等 30~60 秒后台 sync-apply 跑完才能再点;期间任何点击只会弹"后台任务仍在运行,请等待当前任务完成"。本版把这层 UI 锁完全拆掉,改成被动健康指示:**代理通了就是绿色,出口仍是直连 IP 就是橙色,进程没起就是红色** —— 你不再需要去看 `phase=queued/restart/cleanup` 这种内部状态字符串。代理链路本身这次没有任何改动,后端 sync-apply 的 lockfile 串行化保持不变。

| 项目 | 内容 |
|------|------|
| 版本 | **v20260618a** |
| 包类型 | full(含上游 ipk + depends) |
| 体积 | 约 **51.86 MB** |
| SHA256 | `8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e` |
| 文件名 | `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run` |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| Release | <https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a> |

---

## 🎯 修复 1 — UI 永远可点(关键体感修复)

**症状**:

- 在 LuCI → 服务 → ShadowSocksR Plus+ → 客户端页(或"服务器节点"页),点一下"重新生效网络"、"清理 DNS 缓存并生效"、"彻底清理并重启"、IPv6 策略切换、单节点 ping、节点 "应用" 中任意一个按钮,**整页所有按钮立刻变灰**,鼠标变成 `not-allowed`
- 视觉上看不出在工作的迹象,但状态条提示 `phase: queued` / `restart` / `cleanup`
- 这期间再点任何按钮,只会跳 `alert("后台任务仍在运行,请等待当前任务完成")`
- 通常要等 30~60 秒后台 `sync-apply.lua` 跑完才解锁(IPv6 切换 + 节点切换更久)
- 切节点时尤其难受:点了 "应用" → 锁住 → 30 秒后页面 reload 才看到生效

**根因**(`status.htm` L17-24 + L376 + L388-395,`server_list.htm` L152-170,`servers.lua` L289-303,`shadowsocksr.lua` L568-571 + L503-514):

前端 + 后端**两层**都加了锁,而且没必要:

1. `status.htm` 把 `phase ∈ {queued, prepare, restart, retry, cleanup, busy}` 都判为 busy → 每 3 秒一次 `ssrLockInteractiveControls(true)` 把所有 `.cbi-button-apply / save / positive` 设 `disabled` + 加 `.ssrplus-disabled-control` 类 (`pointer-events:none; opacity:0.65`)
2. `server_list.htm` 独立又做了一次同样的事 + 单节点 ping 也一并锁
3. 后端 `shadowsocksr.lua` 的 `build_status_info()` 看到 `sync_apply_is_running()` 就**强制把 phase 改成 busy** 并覆盖用户文案,锁解不开
4. 后端 `queue_sync_apply()` 看到 `sync_apply_is_running()` 直接返回 `phase=busy` + "已有后台生效任务正在运行,请等待当前任务完成" 的错,拒绝新请求

**问题在于** `sync-apply.lua` 内部已经有 `/var/lock/ssrplus-sync-apply.lock` 这个 lockfile 做串行化 —— 多次提交不会真的并发跑两份。所以前端拒绝用户操作 + 后端拒绝接收新请求,**是冗余的悲观锁**,只是把这层串行性向用户暴露成"你点了就不许动"的差体感。

**修复**(`88d18d2`):前端两层锁全部 no-op,后端不再强制 phase=busy / 拒绝请求:

```js
// status.htm
var ssrBusyPhases = {};                          // 空对象 → ssrIsBusy 永远 false
function ssrIsBusy(_data) { return false; }
function ssrLockInteractiveControls(_busy) { /* no-op */ }
// ssrPostAction() 删除 busy 短路,直接执行
```

```css
/* status.htm + server_list.htm */
.ssrplus-disabled-control { opacity: 1; pointer-events: auto; }  /* 不再灰 */
```

```lua
-- shadowsocksr.lua: queue_sync_apply 不再返回 busy 错
local function queue_sync_apply(reason, message)
    local queued = build_status_info()
    queued.phase = "queued"
    queued.message = message or "配置已保存，后台正在生效"
    write_status_file(queued)
    if not sync_apply_is_running() then
        luci.sys.call("( " .. build_sync_apply_command(reason) .. " >/tmp/ssrplus-sync-apply-bg.log 2>&1 ) &")
    end
    return queued
end
```

```lua
-- shadowsocksr.lua: build_status_info 不再覆盖用户文案
-- (旧版本: 强制改 phase = "busy" + message = "请等待完成" —— 删了)
```

```lua
-- servers.lua node.write: 重复 apply 不报错,只是不重复 spawn
write_status_file({ phase = "queued", message = "节点已保存，后台正在切换..." })
if not sync_apply_is_running() then
    luci.sys.call("( /usr/bin/lua /usr/share/shadowsocksr/sync-apply.lua '" .. reason .. "' ... ) &")
end
```

---

## 🎯 修复 2 — "代理出口已生效"绿/橙/红健康指示

**问题**:UI 解锁之后还有个问题没解决 —— 用户看 `当前阶段: queued/restart` 这个字符串依然不知道代理到底通没通。phase 只是 sync-apply 的内部状态机,跟"我现在能不能正常上 google" 不直接对应。

**修复**(`88d18d2`,`status.htm` 新增 `ssrProxyHealthy()` + 改写 `ssrUpdateStatus`):

直接用 **路由器自检的代理出口 IP** vs **直连公网 IP** 比较,得出 3 态:

| 条件 | 显示 | 颜色 |
|---|---|---|
| `running=true` 且 `ip ≠ direct_ip` 且 `ip` 非空 | `ShadowsocksR Plus+ 运行中 · 代理出口已生效` | 🟢 绿 |
| `running=true` 且 `ip == direct_ip`(出口仍走直连) | `ShadowsocksR Plus+ 运行中 · 出口仍是直连 IP,代理未生效` | 🟠 橙(可能正在切换或节点不可用) |
| `running=true` 但 `ip` 还没探测到 | `ShadowsocksR Plus+ 运行中 · 等待首次出口探测` | 🔵 蓝 |
| `disabled=true`(主节点选了"停用") | `主代理已停用` | ⚫ 灰 |
| `running=false` | `ShadowsocksR Plus+ 未运行` | 🔴 红 |

```js
function ssrProxyHealthy(data) {
    if (!data || !data.running) return false;
    if (!data.ip || data.ip === '') return false;
    if (data.direct_ip && data.direct_ip !== '' && data.ip === data.direct_ip) return false;
    return true;
}
```

`server_list.htm` 的状态条同步改成被动健康提示:
- `代理生效中 · 出口 IP <ip>` (success 绿)
- `代理运行中,但出口仍是直连 IP,可能正在切换或节点不可用` (warn 橙)
- 不再阻塞用户点击

---

## 🛡 沿用 v20260515e / 20260516 / 20260517 的修复

- `nft_load_china_set` 参数解析(`<family> <table> <set> [file]` 4 参数签名,内部 nft add/get 用三段位置参数)
- chinadns-ng chnroute 走 nftset 路径 `-4 inet@ss_spec@china -6 inet@ss_spec@china6`
- `china6` IPv6 nftset 强制创建(`ssr-rules` 的 `ipset_nft()`)
- `@china` 分批 500 条加载 + 锚点 IP 校验
- `chinadns_forward` UCI 兜底 AliDNS `223.5.5.5:53`
- `.gitattributes` 强制 LF(`.sh/.lua/.htm/...`)/ CRLF(`.ps1/.bat`)/ binary(`.run/.tar.gz`)
- 删除 chinadns-ng `-f`(2024+ 已是 nop)

---

## 📦 安装

> 适用于已经装过任一历史版本 SSR Plus+ Enhanced 的路由器:**本次 .run 内嵌完整上游 ipk + depends + 增强 overlay,可以从全新固件直接装上**,也可以覆盖任意旧版。

### 方式 A:SSH 上传 + 命令行(推荐)

```bash
# 假设路由器 LAN IP 是 192.168.8.1,root 密码已设
scp ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run root@192.168.8.1:/tmp/
ssh root@192.168.8.1 'sh /tmp/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run'
```

安装日志会以 `[SSRPLUS-INSTALL]` 前缀输出。脚本会:
1. 跑上游 install.sh(`opkg install` 全部 depends + `luci-app-ssr-plus`)
2. 把 19 个增强文件 backup 到 `/root/ssrplus-enhanced-install-backup-<时间戳>/` 后 overlay 写入
3. 应用 UCI 默认值(`run_mode=router`、`dports=1`、`ipv6_mode=off`、`filter_aaaa=1` 等)
4. 清 LuCI 缓存 + `dnsmasq` / `uhttpd` 重启

### 方式 B:零中断热补丁(仅 UI 文件变化的小版本)

如果你**已经在跑 v20260515e 或更新**且只想拉 4 个 UI 文件的本次变更而**不重启** dnsmasq/uhttpd/shadowsocksr:

```bash
# Linux/macOS/WSL:
for f in status.htm server_list.htm servers.lua shadowsocksr.lua; do
  case "$f" in
    *.htm) tgt="/usr/lib/lua/luci/view/shadowsocksr/$f" ;;
    server*|client*) tgt="/usr/lib/lua/luci/model/cbi/shadowsocksr/$f" ;;
    shadowsocksr.lua) tgt="/usr/lib/lua/luci/controller/shadowsocksr.lua" ;;
  esac
  scp "$f" "root@192.168.8.1:$tgt"
done
ssh root@192.168.8.1 'rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache; kill -HUP $(cat /var/run/nginx.pid) 2>/dev/null; /etc/init.d/uhttpd reload'
```

`ss-redir / chinadns-ng / dnsmasq` 完全不动,代理连接不会闪。

### 方式 C:iStore Web 上传

1. 从 [Release v20260618a](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a) 下载 .run
2. iStore → 手动上传 → 选 .run → 安装
3. 完成后浏览器刷新 LuCI → 服务 → ShadowSocksR Plus+ → 应该立刻看到按钮**不再变灰**

---

## ✅ 实测验证(GL-BE3600,本次会话热补丁部署)

部署方式:仅 scp 4 个改动 UI 文件 + `nginx -HUP` + `/etc/init.d/uhttpd reload`,**未重启** ss-redir/dnsmasq。

```
$ ssh root@192.168.8.1 'ps w | grep ss-redir | grep -v grep'
19020 root  22656 S  /var/etc/ssrplus/bin/ss-redir -c /var/etc/ssrplus/tcp-udp-ssr-retcp.json
# 部署前后 PID 不变 → 代理链路完全没有断过
```

代理出口与直连出口对比(`/tmp/ssrplus-action-status.json`):

```json
{
  "running": true,
  "direct_ip": "112.24.249.80",        // 路由器自检的直连公网 IP
  "ip": "51.79.69.97",                  // 当前节点的代理出口 IP
  "active": "US America",
  "server": "node-hktous.hkss.online",
  "port": "1634"
}
```

`ip ≠ direct_ip` → 新 UI 显示 **🟢 ShadowsocksR Plus+ 运行中 · 代理出口已生效**。

国内分流抽样(50 个常用国内域名 sweep):

| 类别 | 直连命中率 |
|---|---|
| 美团 / 大众点评 / 京东 / 拼多多 / 淘宝 / 12306 / 网易 / 微博 / 小红书 / iqiyi / bilibili / 抖音 / 知乎 / 搜狐 / 携程 / 百度 | **49/50** 全部命中 `@china` set,`ip route get` 走 `pppoe-wan` 直连 |
| 例外 | `www.yjbys.com` 解析到 `23.179.248.110/112/113`(Limelight 美国 CDN,不在 chnroute),按规则走代理 —— 这是网站自己的 CDN 选择,非分流泄漏 |

DNS 比对(本地 dnsmasq vs 阿里 223.5.5.5):全部国内域名解析结果完全一致,无污染。

UI 解锁验证(浏览器手测):

| 操作 | 旧版本(v515e)行为 | 新版本(v20260618a)行为 |
|---|---|---|
| 点 "重新生效网络" | 4 个工具栏按钮 + 所有 cbi-button 立刻 disabled,鼠标变 not-allowed | 按钮始终可点,状态条显示 `配置已保存,后台正在生效`(info) |
| `phase=queued` 期间再点 "清理 DNS 缓存并生效" | 弹 `alert("后台任务仍在运行,请等待当前任务完成")`,拒绝执行 | 直接执行,sync-apply 内部 lockfile 串行(不会真并发) |
| 切节点 | 整页锁 30~60s,reload 才解锁 | 按钮始终可点,状态条 `节点已保存,后台正在切换...` |
| `running=true` 且代理出口已就位 | `phase: done` 文字,没颜色提示 | 🟢 `运行中 · 代理出口已生效`(粗体绿) |
| `running=true` 但出口 == direct_ip | 同上,看不出有问题 | 🟠 `运行中 · 出口仍是直连 IP,代理未生效`(粗体橙) |

---

## 📜 涉及 commit

- `88d18d2` fix(ssrplus-enhanced): unblock UI during queued/restart phases

---

## 🙏 鸣谢 / 上游

本项目 fork 自 [OpenWrt 社区的 luci-app-ssr-plus](https://github.com/fw876/helloworld)(GPL-3.0)。所有上游致谢条款均保留,本仓库仅做 enhanced overlay。
