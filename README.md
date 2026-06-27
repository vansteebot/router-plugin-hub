# Router Plugin Hub

[![Repo](https://img.shields.io/badge/GitHub-router--plugin--hub-181717?logo=github)](https://github.com/vansteebot/router-plugin-hub)
[![Platform](https://img.shields.io/badge/Platform-GL.iNet%20%2F%20OpenWrt-4c6ef5)](https://github.com/vansteebot/router-plugin-hub)
[![Package](https://img.shields.io/badge/Current-SSR%20Plus%2B%20Enhanced-10b981)](https://github.com/vansteebot/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
[![Releases](https://img.shields.io/badge/Release-v20260618a-f59e0b)](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a)
[![License](https://img.shields.io/badge/License-GPL--3.0-9333ea)](#上游)

Router Plugin Hub 是面向路由器插件增强开发的总仓库。当前主包 **SSR Plus+ Enhanced** 是对上游 `luci-app-ssr-plus` 的 LuCI 界面 + 后端脚本增强,聚焦三件事:**严格国内分流不漏流量**、**UI 永远可点不卡死**、**一次 .run 安装无残留**。

> 🆕 **刚买回路由器、之前没碰过 OpenWrt / iStore 的人**,直接看 **[👉 全新手完整教程](docs/tutorials/getting-started.md)** —— 从开箱激活 → 一键叠加 iStore 商店 → 上传我们的 `.run` → 4 条防 WebRTC/QUIC 泄漏规则 → 浏览器自测,一路命令照抄即可。已经有 iStoreOS 环境的老用户可以直接看下面的"📦 最新版本"和"🚀 完整安装教程"。

---

## 📦 最新版本

| 项目 | 内容 |
|------|------|
| 版本 | **v20260618a** |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| 包类型 | full(含上游 ipk + depends,可全新安装) |
| 完整包体积 | 约 **51.86 MB** |
| 安装包文件名 | `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run` |
| 本仓库构建路径(本地) | `packages/ssrplus-enhanced/release/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run` |
| SHA256 | `8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e` |
| 下载 | [Release 页面](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a) · [直链 `.run`](https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run) · [全部 Releases](https://github.com/vansteebot/router-plugin-hub/releases) |

---

## 🚀 完整安装教程

> 👉 **从未装过 iStoreOS / OpenWrt?** 别从这一段开始 —— 先去 **[新手完整教程](docs/tutorials/getting-started.md)**,那里覆盖了开箱激活 → 一键叠加 iStore 商店 → 上传 `.run` → WebRTC 防泄漏 → 浏览器验证整条路径。下面这段假设你的路由器**已经在跑** iStoreOS 风格固件,且 LuCI 已经能进。

下面是一条从"已有 iStoreOS"到"代理生效绿灯亮起"的最短路径。命令全部针对本仓库的 .run 安装包,**不依赖任何第三方脚本服务器**,所有 URL 都指向你自己的 GitHub Release。

### 1. 准备前置条件

- 一台支持的路由器 —— 目前发布物锁定 **aarch64_cortex-a53 / OpenWrt r126**(实测设备:GL-iNet BE3600,使用 iStoreOS 风格固件或官方固件均可)
- 路由器已经能正常上网(WAN 拨号成功)
- 路由器 SSH 已开启,知道 root 密码
- 你自己的代理节点(SS / SSR / V2Ray / Trojan / Hysteria2 / TUIC 等任意一种)

> **不支持的平台**:本 `.run` 内嵌的 ipk 是 `aarch64_cortex-a53` 架构 + `r126` 基线。其它芯片(mt798x / ipq40xx / x86_64...)请自行使用 `packages/ssrplus-enhanced/` 下的源码 + 自家上游 ipk,用 `build-full-package-from-upstream.ps1 -Arch <你的架构> -BaseRelease <r号>` 重新打包。

### 2. 连上路由器 SSH

```bash
ssh root@192.168.8.1     # 192.168.8.1 改成你的路由器 LAN IP
```

> 如果遇到 `Host key verification failed` 这类报错,清掉本地旧 host key 再重试:`ssh-keygen -R 192.168.8.1`。

### 3. 一键安装(推荐 · 全新机或覆盖旧版都可以)

直接在路由器 SSH 终端里粘贴这一行(它会从 GitHub Releases 下载 .run 并执行):

```bash
wget -O /tmp/ssrp-enhanced.run "https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run" && sh /tmp/ssrp-enhanced.run
```

或者用 `curl`(部分 OpenWrt 内置 curl 而非 wget):

```bash
curl -L -o /tmp/ssrp-enhanced.run "https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run" && sh /tmp/ssrp-enhanced.run
```

安装日志以 `[SSRPLUS-INSTALL]` 前缀输出。**整个过程约 30~60 秒**,期间会:

1. 跑上游 install.sh(`opkg install` 所有 depends + `luci-app-ssr-plus`)
2. 备份目标位置原文件到 `/root/ssrplus-enhanced-install-backup-<时间戳>/`
3. Overlay 写入 19 个增强文件
4. 应用 UCI 默认值(`run_mode=router`、`ipv6_mode=off`、`filter_aaaa=1` 等)
5. 重启 `dnsmasq` + `uhttpd`(代理进程 `ss-redir` 不会重启)

### 4. 校验下载完整性(可选但推荐)

```bash
echo "8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e  /tmp/ssrp-enhanced.run" | sha256sum -c -
```

应返回 `/tmp/ssrp-enhanced.run: OK`。SHA 不一致就别装,重新下载或者去 Releases 页核对最新值。

### 5. 装完后访问

浏览器打开你的路由器后台(LuCI),路径不一定固定为某个端口 —— 大多数情况下:

- 官方 GL.iNet 固件 + LuCI:`http://192.168.8.1/cgi-bin/luci/`
- iStoreOS 风格固件:`http://192.168.8.1/cgi-bin/luci/` 或 `http://192.168.8.1:8080/cgi-bin/luci/`(端口看你的固件)

进入 **服务(Services) → ShadowSocksR Plus+**,你应该看到顶部状态条:

| 视觉 | 含义 |
|---|---|
| 🟢 `ShadowsocksR Plus+ 运行中 · 代理出口已生效` | 一切正常 |
| 🟠 `运行中 · 出口仍是直连 IP,代理未生效` | 进程起来了但出口 IP 还没切走,可能正在重建或节点不可用 |
| 🔵 `运行中 · 等待首次出口探测` | 刚装好/刚切节点,稍等 5~15s |
| 🔴 `未运行` | 进程没起,检查日志 |

### 6. 添加你的代理节点

两种方式选一个:

**A. 服务器节点 → 添加(单条)** —— 适合手动填一两个节点

LuCI → 服务 → ShadowSocksR Plus+ → 服务器节点 → "添加" → 填类型/服务器/端口/加密/密码 → "保存并应用"。

**B. SS 批量导入** —— 适合从订阅或 .txt 文件粘贴多条 `ss://`

LuCI → 服务 → ShadowSocksR Plus+ → 服务器节点 → 下方"SS 批量导入"区块 → 粘贴或上传 → "批量解析 / 覆盖导入"。

添加后回到 **客户端** 页,在"主服务器"下拉选刚加的节点 → 点 "保存 & 应用"。状态条变 🟢 即生效。

### 7. 进阶:带参数 / 静默安装

如果你要写自动化部署脚本,可以直接拼出 .run 的下载 + 执行:

```bash
# 完全无交互(.run 内部本来就不交互),适合 ansible/curl-pipe 场景
TARGET=/tmp/ssrp-enhanced.run
wget -qO "$TARGET" "https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run"
sha256sum -c <(echo "8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e  $TARGET")
sh "$TARGET" 2>&1 | tee /tmp/ssrp-install.log
```

### 8. 零中断热补丁(仅 UI 文件小版本)

如果你**已经在跑 v20260515e 或更新**,只想拉本次 UI 改动而**不重启** dnsmasq/uhttpd/shadowsocksr 任何服务,代理连接保持不断:

```bash
# 在一台已经 git clone 了本仓库的电脑上跑(macOS/Linux/WSL)
cd packages/ssrplus-enhanced
for src in status.htm:view server_list.htm:view servers.lua:cbi shadowsocksr.lua:controller; do
  file="${src%%:*}"; kind="${src##*:}"
  case "$kind" in
    view)       dst="/usr/lib/lua/luci/view/shadowsocksr/$file" ;;
    cbi)        dst="/usr/lib/lua/luci/model/cbi/shadowsocksr/$file" ;;
    controller) dst="/usr/lib/lua/luci/controller/$file" ;;
  esac
  scp "$file" "root@192.168.8.1:$dst"
done
ssh root@192.168.8.1 'rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache; [ -f /var/run/nginx.pid ] && kill -HUP $(cat /var/run/nginx.pid); /etc/init.d/uhttpd reload'
```

`ss-redir / chinadns-ng / dnsmasq` 的 PID 不变,代理链路不会闪。

### 9. 卸载 / 回滚到旧版

每次安装都会把原文件备份到 `/root/ssrplus-enhanced-install-backup-<时间戳>/`,目录结构镜像原路径。回滚:

```bash
ssh root@192.168.8.1
ls /root/ | grep ssrplus-enhanced-install-backup    # 找到你要回到的那个时间戳
BAK=/root/ssrplus-enhanced-install-backup-XXXXXXXX-XXXXXX
# 把备份目录里的每个文件 cp 回原位(目录结构镜像 / 路径)
cd "$BAK" && find . -type f | while read f; do
  src="$f"; dst="/${f#./}"
  cp -a "$src" "$dst"
done
rm -rf /tmp/luci-*cache; /etc/init.d/uhttpd reload
```

完全卸载(连上游 ipk 也移除):

```bash
opkg remove --autoremove luci-app-ssr-plus shadowsocksr-libev-ssr-redir shadowsocksr-libev-ssr-local 2>/dev/null
rm -rf /etc/config/shadowsocksr /etc/ssrplus /usr/share/shadowsocksr /var/etc/ssrplus
rm -f /etc/init.d/shadowsocksr /usr/bin/ssr-switch /usr/bin/ssr-rules
/etc/init.d/uhttpd reload
```

---

## 🩺 常见问题 / 故障排查

### 装完后 LuCI 看不到 "ShadowSocksR Plus+" 菜单
LuCI 缓存没清干净。SSH 到路由器跑:
```bash
rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache
/etc/init.d/uhttpd restart
# 浏览器 Ctrl+Shift+R 强刷
```

### 状态条一直显示 🟠 "出口仍是直连 IP"
代理进程起来了,但路由器自检的出口 IP 跟你直连的公网 IP 一样 —— 说明流量没走代理。检查清单:
1. **节点选错了** — 客户端页"主服务器"下拉确认选的是国外节点,不是"停用"
2. **节点不可用** — 服务器节点页点"批量测速",看延迟列。延迟 `未连通` 的节点换一个
3. **国内 IP 集没加载** — `nft list set inet ss_spec china | wc -l` 应该返回 3500+,如果是 0 → `/etc/init.d/shadowsocksr restart`
4. **chinadns-ng 进程残留太多** — `ps w | grep chinadns-ng | grep -v grep | wc -l` 应该是 2,如果是 8/12 等(多份残留)→ `pkill -9 -f chinadns-ng; /etc/init.d/shadowsocksr restart`

### 装完后按钮还是变灰
没刷新浏览器,或者浏览器缓存了旧 JS。Ctrl+Shift+R 强制刷新。仍然不行就清 LuCI 缓存:
```bash
ssh root@192.168.8.1 'rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache; /etc/init.d/uhttpd restart'
```

### 国内某个站(比如某 CDN 用了境外节点的站)被误判走代理
这不一定是 bug。某些国内服务的 CDN(尤其是教育/小流量站)可能选择了境外 IP(Limelight、Cloudflare 等),按规则会走代理。
- 如果你信任该域名,加入直连白名单:LuCI → 服务 → ShadowSocksR Plus+ → 访问控制 → "强制走 WAN 列表" 添加该域名/IP
- 如果你想强制 DNS 解析到 apex 的国内 IP:在 LuCI → 网络 → DHCP/DNS 加 `address=/yourdomain.com/<国内 IP>` 行

### `Host key verification failed` SSH 连不上
路由器重装或 host key 重置后会出现。清掉旧 known_hosts 条目即可:
```bash
ssh-keygen -R 192.168.8.1
```

### opkg 安装失败 / depends 装不上
安装日志看到 `opkg_install_cmd: Cannot install package ...`。常见原因:
- 上游 ipk 与当前固件版本不匹配 → 确认固件是 OpenWrt r126(`uname -a` 看 r 号),不是就需要自行 build
- 磁盘空间不够 → `df -h` 看 `/overlay` 剩余空间,< 30 MB 时清掉 `/tmp/opkg-lists/*` 重试

---

## ✨ 功能特性

### 严格国内分流
- 🇨🇳 **`@china` nftset 分批加载** — 单次几万条 `nft add element` 会被内核截断,改为 500 条一批 + 锚点 IP 校验
- 🔀 **chinadns-ng chnroute 走 nftset 路径** — `-4 inet@ss_spec@china -6 inet@ss_spec@china6`,跟新版 chinadns-ng (2024+) 对齐
- 🌐 **`china6` IPv6 set 强制创建** — `ssr-rules` 的 `ipset_nft()` 主动建空 `china6 (ipv6_addr)`,daemon persistence 自动写入 `99-shadowsocksr.nft`

### UI 体验
- 🟢 **代理生效健康指示** — 绿/橙/红/灰四态直接告诉你"代理通没通",不用看 phase 字符串
- 🔓 **按钮永远可点** — 移除前后端的悲观锁,sync-apply 的串行性靠 lockfile 自然实现
- 📊 **代理出口 vs 直连 IP 对比** — 状态条同时显示两者,一眼看出代理是否生效

### 节点导入
- 📥 **SS 节点批量导入** — `ss://` 链接,TXT 文件上传或直接粘贴
- 📥 **Trojan 节点批量导入** — `trojan://` 链接,通过 xray 运行
- 🔗 **订阅链接解析** — 从 URL 拉取 + base64 解码批量导入
- 📋 **批量选择 / 删除** — 服务器节点列表支持全选 + 批量删

### 稳定性 & 安全默认
- ⚡ **安装容错** — opkg 仓库不可达不会中断安装
- 🔄 **配置自动修复** — 每次应用时补全关键 UCI 项
- 📶 **IPv6 默认关 + AAAA 过滤开启** — 避免 IPv6 直连绕过代理
- 🛡️ **`server_subscribe.ss_type` 自动设值** — 防止代理二进制启不来导致断网

---

## 📋 更新日志 (v20260618a)

| 说明 |
|------|
| **UI 永远可点(关键体感)** — 移除前后端两层悲观锁:`status.htm` 的 `ssrBusyPhases` 改空对象,`ssrLockInteractiveControls` 改 no-op,`.ssrplus-disabled-control` CSS 不再灰 + pointer-events 恢复;`server_list.htm` 的 `statusIsBusy` 永远 false,单节点 ping / 节点 apply 不再 gate on applyLocked;后端 `shadowsocksr.lua` 的 `queue_sync_apply` 不再返回 `phase=busy` 错,`build_status_info` 不再强制覆盖文案,`servers.lua` 的 `node.write` 不再拒绝重复请求 —— sync-apply 的串行性靠 lockfile 自然保证。 |
| **"代理出口已生效" 健康指示** — `status.htm` 新增 `ssrProxyHealthy()`(`running && ip && ip ≠ direct_ip`),`ssrUpdateStatus` 输出绿/橙/蓝/红/灰 5 态文本,直接告诉用户"代理通没通"而不是 `phase: queued`。`server_list.htm` 的状态条同步改成被动健康提示。 |

完整更新说明 + 实测验证数据:[docs/releases/ssrplus-enhanced-20260618a.md](docs/releases/ssrplus-enhanced-20260618a.md)

历史版本(按时间倒序):
[20260618a](docs/releases/ssrplus-enhanced-20260618a.md) ·
[20260517](docs/releases/ssrplus-enhanced-20260517.md) ·
[20260516](docs/releases/ssrplus-enhanced-20260516.md) ·
[20260515e](docs/releases/ssrplus-enhanced-20260515e.md) ·
[20260515c](docs/releases/ssrplus-enhanced-20260515c.md) ·
[20260515](docs/releases/ssrplus-enhanced-20260515.md) ·
[20260514](docs/releases/ssrplus-enhanced-20260514.md) ·
[20260513](docs/releases/ssrplus-enhanced-20260513.md) ·
[20260512](docs/releases/ssrplus-enhanced-20260512.md) ·
[20260511](docs/releases/ssrplus-enhanced-20260511.md) ·
[20260508](docs/releases/ssrplus-enhanced-20260508.md)

---

## 🗂️ 仓库结构

```text
router-plugin-hub/
├─ packages/
│  ├─ ssrplus-enhanced/     # SSR Plus+ 增强版源码
│  │  ├─ *.lua *.htm        # LuCI controller / cbi / view
│  │  ├─ *.remote.sh        # 路由器侧脚本(/etc/init.d, /usr/bin)
│  │  ├─ build-full-package-from-upstream.ps1   # 发版用 full builder
│  │  ├─ build-release-package.ps1              # overlay builder(开发用,不发版)
│  │  └─ release/<pkg>/     # 本地构建产物(.gitignored)
│  └─ openclash-enhanced/   # 计划中
├─ docs/
│  ├─ releases/             # 每版本的详细更新说明
│  ├─ install.md            # 安装指南
│  └─ release-process.md    # 维护者发版流程
├─ scripts/
│  └─ publish_github_release.py   # 纯 urllib 的 GitHub Releases 发版器
└─ README.md
```

### 当前维护包

- **`packages/ssrplus-enhanced`** — SSR Plus+ 增强版
  - 严格国内 IP 分流(`@china` nftset + chinadns-ng 双引擎)
  - LuCI UI 重写(状态健康指示、按钮不卡死、节点批量管理)
  - SS / SSR / V2Ray / Trojan / Hysteria2 / TUIC / Naiveproxy 多协议
  - 自动切换 + 监控
  - IPv6 / DNS 安全默认值
  - 一键 `.run` 完整离线安装(含上游 ipk + depends)

---

## 🔗 快速链接

- [📦 GitHub Releases(下载安装包)](https://github.com/vansteebot/router-plugin-hub/releases)
- [📁 SSR Plus+ 源码](https://github.com/vansteebot/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
- [📖 历史更新说明](https://github.com/vansteebot/router-plugin-hub/tree/main/docs/releases)
- [🐛 问题反馈(Issues)](https://github.com/vansteebot/router-plugin-hub/issues)

---

## 🛠️ 维护者:发版流程

1. 在 `packages/ssrplus-enhanced/` 下修改源码
2. 发布 **完整** `.run`:运行 **`build-full-package-from-upstream.ps1-Version <yyyyMMdd[a-z]>`**(需本机已有上游 `ssrp_*.upstream.run`),得到约 **50MB+** 的 `enhanced_full_*.run`。**不要**用 `build-release-package.ps1` 代替发布物(该脚本仅生成约几十 KB 的 `enhanced_overlay_*.run` 覆盖层,仅用于开发期增量更新)
3. 在 `docs/releases/ssrplus-enhanced-<datecode>.md` 写完整更新说明(必须含真实路由器验证输出)
4. README 顶部"最新版本"表 + 更新日志 + 历史列表同步更新版本号 + SHA256
5. 通过 `scripts/publish_github_release.py` 上传 `.run` + `SHA256SUMS.txt` + `README.md` 到 GitHub Releases(`GITHUB_TOKEN` 需 Contents:write 权限)

---

## 🙏 上游

- 本项目基于 [`fw876/helloworld`](https://github.com/fw876/helloworld) (`luci-app-ssr-plus`) 增强,GPL-3.0
- 上游致谢链路完整保留,本仓库仅做 enhanced overlay 与发布工程化

---

## 计划扩展

- OpenClash 增强模块(基于本仓库相同的 build/release pipeline)
- 路由器诊断工具集(DNS 分流 sweep / 节点健康巡检 / 带宽瓶颈定位)
- 更多路由器型号 / OpenWrt 基线 支持(mt798x / ipq40xx / x86_64)
