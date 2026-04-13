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
| 版本 | **20260413** |
| 平台 | GL-BE3600 / aarch64_cortex-a53 / OpenWrt r126 |
| 大小 | ~52 MB |
| 下载 | [GitHub Releases](https://github.com/vansteebot/router-plugin-hub/releases) |

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

## 📋 更新日志 (20260413)

| 提交 | 说明 |
|------|------|
| `9128e73` | 支持 trojan:// 节点导入（通过 xray） |
| `8c517ea` | 修复断网：确保 ss_type=ss-rust + DNS 安全默认值 |
| `5f0e2a8` | 测速改用 tcping-simple（无需 nping） |
| `867a624` | 测速改用 nping + 安装脚本容错 |
| `4ed5705` | 修复导入脚本 end→fi 语法错误 |
| `394bdd5` | 修复节点选择/应用状态 + 批量删除功能 |

完整更新说明：[docs/releases/ssrplus-enhanced-20260413.md](docs/releases/ssrplus-enhanced-20260413.md)

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
2. 运行 `build-full-package-from-upstream.ps1` 构建 `.run` 安装包
3. 在 `docs/releases/` 下编写更新说明
4. 通过 GitHub Releases 上传 `.run` 文件（不提交到 git 历史）

---

## 计划扩展

- OpenClash 增强模块
- 路由器诊断工具集
- 统一安装器和元数据
- 更多路由器型号支持
