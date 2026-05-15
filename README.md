# Router Plugin Hub

[![Repo](https://img.shields.io/badge/GitHub-router--plugin--hub-181717?logo=github)](https://github.com/vansteebot/router-plugin-hub)
[![Platform](https://img.shields.io/badge/Platform-GL.iNet%20%2F%20OpenWrt-4c6ef5)](https://github.com/vansteebot/router-plugin-hub)
[![Package](https://img.shields.io/badge/Current-SSR%20Plus%2B%20Enhanced-10b981)](https://github.com/vansteebot/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
[![Releases](https://img.shields.io/badge/Release-GitHub%20Releases-f59e0b)](https://github.com/vansteebot/router-plugin-hub/releases)

Router Plugin Hub 是面向路由器插件增强开发的总仓库，统一管理插件源码、打包脚本、发布说明和可安装文件。

---

## 📦 下载安装

### 最新版本

| 项目 | 内容 |
|------|------|
| 版本 | **v20260515e** |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| 完整包体积 | 约 **54.4 MB**（`build-full-package-from-upstream.ps1`；含 ipk/depends） |
| 安装包文件名 | `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run` |
| 本仓库构建路径 | `packages/ssrplus-enhanced/release/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run` |
| 校验 | SHA256 `fc8b6abedba0c13984c428501aaee5e830bbdc895c795699916dd9fa751462d1` |
| 下载 | [Release 页面](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260515e) · [直链 `.run`](https://github.com/vansteebot/router-plugin-hub/releases/download/v20260515e/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260515e.run) · [全部 Releases](https://github.com/vansteebot/router-plugin-hub/releases) |

### 安装方式

**方式一：SSH 命令行安装**
```bash
# 上传到路由器
scp ssrp_*.run root@192.168.8.1:/tmp/

# SSH 登录后执行
chmod +x /tmp/ssrp_*.run && /tmp/ssrp_*.run
```

**方式二：iStore 上传安装**
1. 从 GitHub Releases 下载 `.run` 安装包
2. 在路由器 iStore 中手动上传
3. 直接安装即可

---

## ✨ 功能特性

### 核心功能
- 🔧 **节点选择修复** — 下拉菜单选择节点不再跳回"停用"
- 🚀 **异步应用流程** — 更安全的保存/生效/重建流程，状态实时反馈
- 📊 **可靠测速** — 基于 tcping-simple，无需额外依赖，CGI 环境下稳定工作
- 🛡️ **防断网保护** — 自动确保 `server_subscribe.ss_type=ss-rust`，防止代理二进制未启动导致全网断网
- 🌐 **DNS 安全默认值** — 自动设置 `pdnsd_enable=2` + `tunnel_forward=8.8.8.8:53` + `safe_dns_tcp=1`

### 节点导入
- 📥 **SS 节点批量导入** — 支持 `ss://` 链接，一行一个，TXT 文件上传或直接粘贴
- 📥 **Trojan 节点批量导入** — 支持 `trojan://` 链接，自动通过 xray 运行（无需原生 trojan 二进制）
- 🔗 **订阅链接解析** — 支持从订阅 URL 拉取、base64 解码后批量导入
- 📋 **批量选择/删除** — 服务器节点列表支持全选、批量删除

### 稳定性
- ⚡ **安装容错** — opkg 仓库不可达时不会中断安装
- 🔄 **配置自动修复** — 每次应用时自动检查并补全关键配置项
- 📶 **IPv6 安全默认** — 自动关闭 IPv6 代理，避免泄漏

---

## 📋 更新日志 (v20260515e)

| 说明 |
|------|
| **`nft_load_china_set` 参数解析修复（关键）** — 函数签名只取 3 个位置参数 `<table> <set> [file]`，但调用站每次传 4 个 (`inet ss_spec china /etc/ssrplus/china_ssr.txt`)，结果第 3 个参数 `china` 被当成文件路径，永远返回 `china route file missing: china`，**`@china` 集合一直没被加载**。之所以表面看起来在工作，是因为旧版 persistence 文件残留了真实数据；一旦那个 persistence 被任何重建动作刷新，`@china` 变空，所有 TCP/UDP 落入末位代理规则。函数签名改为 4 个参数 `<family> <table> <set> [file]`，并把内部所有 `nft add/get element` 改用三段 family/table/set（`ssr-rules`）。 |
| **chinadns-ng chnroute 走 nftset 路径** — `-4 china` 是旧 ipset 语法，新版 chinadns-ng (2024+) 看到没 `@` 的 setname 会去找 ipset → 本路由器只有 nftables → chnroute 永远 fail → 所有 chnlist 答复都被忽略，trusted 答复（走代理出口的 1.1.1.1，加拿大 GeoDNS）总是胜出 → baidu/qq/bili 拿到 `103.235.46.x` / 腾讯云海外 / Akamai 海外。改成 `-4 inet@ss_spec@china -6 inet@ss_spec@china6`（`shadowsocksr.init.remote.sh`）。 |
| **`china6` IPv6 nftset 持久化** — chinadns-ng 在 `-4` 用 nftset 路径时强制把 `-6` 默认值（`chnroute6`）也按 nftset 解析，没 `@` → `invalid family: 'chnroute6'` → 启动失败。`ssr-rules` 的 `ipset_nft()` 在主 `china` set 旁创建空的 `china6 (ipv6_addr; interval; auto-merge)`，daemon 的 persistence exporter 自动把它写进 `99-shadowsocksr.nft`，重启后仍然存在。 |
| **`@china` nftset 分批加载** — 单次几万条 `nft add element` 在路由器上会被内核静默截断。`nft_load_china_set` 分 500 条流式写入并校验锚点 IP。 |
| **`chinadns_forward` UCI 兜底** — LuCI sync-apply / DNS-flush 会瞬间清空 `chinadns_forward`，没默认值时 init.d 静默跌入"直通 WAN DNS"分支。在两处 lookup 都 fallback 到 AliDNS `223.5.5.5:53`。 |
| **`.gitattributes` 根治 CRLF** — Windows `core.autocrlf=true` 让 `.sh`/`.lua`/`.htm` 进 git 后变 CRLF。`.sh`/`.lua`/`.htm`/`.conf`/`.cron`/`.list`/`.txt`/`.json`/`.yaml`/`.md` 强制 `eol=lf`；`.ps1`/`.bat`/`.cmd` 保留 CRLF；`.run`/`.tar.gz` 等标记 binary。 |
| **删除 `chinadns-ng -f`** — 2024+ 版本 `-f` 已是 nop（`fair mode is the only mode now`）。 |

完整更新说明：[docs/releases/ssrplus-enhanced-20260515e.md](docs/releases/ssrplus-enhanced-20260515e.md)

历史版本（按时间倒序）：
[20260515c](docs/releases/ssrplus-enhanced-20260515c.md) ·
[20260517](docs/releases/ssrplus-enhanced-20260517.md) ·
[20260516](docs/releases/ssrplus-enhanced-20260516.md) ·
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
│  └─ openclash-enhanced/   # OpenClash（预留）
├─ docs/
│  ├─ releases/             # 版本更新说明
│  └─ install.md            # 安装指南
├─ scripts/                 # 工具脚本
└─ README.md
```

### 当前维护包

- **`packages/ssrplus-enhanced`** — SSR Plus+ 增强版
  - LuCI 界面优化（状态卡片、节点管理）
  - 异步保存/生效流程
  - SS / Trojan 节点导入工具
  - 自动切换与监控
  - IPv6 / DNS 安全控制
  - `.run` 完整打包构建脚本

---

## 🔗 快速链接

- [📦 GitHub Releases（下载安装包）](https://github.com/vansteebot/router-plugin-hub/releases)
- [📁 SSR Plus+ 源码](https://github.com/vansteebot/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
- [📖 安装指南](https://github.com/vansteebot/router-plugin-hub/blob/main/docs/install.md)
- [📋 更新说明](https://github.com/vansteebot/router-plugin-hub/tree/main/docs/releases)

---

## 发布流程

1. 在 `packages/ssrplus-enhanced/` 下修改源码
2. 发布 **完整** `.run`：运行 **`build-full-package-from-upstream.ps1`**（需本机已有上游 `ssrp_*.upstream.run`），得到约 **50MB+** 的 `enhanced_full_*.run`。**不要**用 `build-release-package.ps1` 代替发布物（该脚本仅生成约几十 KB 的 **`enhanced_overlay_*.run`** 覆盖层）。
3. 在 `docs/releases/` 下编写更新说明
4. 通过 GitHub Releases 上传完整 `.run`（不提交到 git 历史）

---

## 计划扩展

- OpenClash 增强模块
- 路由器诊断工具集
- 统一安装器和元数据
- 更多路由器型号支持
