# SSR Plus+ Enhanced — 20260413

## 版本信息

- 版本：20260413
- 平台：GL-BE3600 / aarch64_cortex-a53-190 / OpenWrt r126
- 安装包：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260413.run`
- 大小：~52 MB

## 重要修复

### 🛡️ 修复启用节点后全网断网（关键修复）

**问题**：在新路由器上安装后，启用任意节点会导致整个网络（包括有线和无线）完全断网。

**根因**：初始化脚本从 `server_subscribe.ss_type` 读取代理二进制类型（`ss-rust` → `sslocal`，`ss-libev` → `ss-redir`）。新路由器上该字段为空，导致无法匹配到任何二进制程序，代理进程未启动。但 nftables 重定向规则已经生效，所有流量被导向不存在的本地端口，形成黑洞。

**修复**：
- 安装脚本自动设置 `server_subscribe.ss_type=ss-rust`
- 每次应用/保存时自动检查并补全该字段
- 导入节点后自动设置
- 同时补全 DNS 安全默认值：`pdnsd_enable=2`、`tunnel_forward=8.8.8.8:53`、`safe_dns_tcp=1`

### 📊 修复测速显示 fail

**问题**：Web 界面中测速全部显示 "fail"，实际节点可用。

**根因**：
1. `nixio.socket:connect` 在 uhttpd CGI 环境下返回 false（CLI 下正常）
2. `nping` 不在上游包列表中，新路由器上不存在

**修复**：改用 `tcping-simple`（上游包列表中已包含），在所有环境下稳定工作。

### 📥 修复批量导入失败

**问题**：上传 TXT 文件批量导入节点失败。

**根因**：`import-ss-txt.sh` 中有4处使用了 Lua 语法 `end` 而非 Shell 语法 `fi`。

**修复**：修正为 `fi`，通过 `sh -n` 语法检查。

### 🔧 修复节点选择跳回停用

**问题**：在客户端页面选择节点后，下拉菜单自动跳回"停用"。

**修复**：修正 `normalize_server_section` 参数传递、`global` 段创建逻辑、节点保存时使用命名段。

## 新功能

### 📥 Trojan 节点导入

支持 `trojan://` 链接批量导入，通过 xray 运行（原生 trojan 二进制缺少 libboost 依赖）。

- 格式：`trojan://password@server:port#别名`
- 自动设置：`type=v2ray`、`v2ray_protocol=trojan`、`tls=1`、`fingerprint=chrome`
- 支持订阅链接 base64 解码

### ✂️ 批量选择/删除

服务器节点列表新增"全选"和"删除选中"按钮。

### ⚡ 安装容错

`opkg update` 失败（如 iStore 仓库不可达）不再中断整个安装流程。

## 提交记录

| 提交 | 说明 |
|------|------|
| `9128e73` | feat: 支持 trojan:// 节点导入（通过 xray） |
| `8c517ea` | fix: 确保 ss_type=ss-rust 防止断网 |
| `5f0e2a8` | fix: 测速改用 tcping-simple |
| `867a624` | fix: 测速改用 nping + 安装容错 |
| `4ed5705` | fix: 导入脚本 end→fi 语法错误 |
| `394bdd5` | fix: 节点选择/应用状态 + 批量删除 |

## 修改文件

- `shadowsocksr.lua` — 主控制器（测速、应用、ss_type 检查、DNS 默认值）
- `client.lua` — 客户端配置（global 段创建、ss_type 保障）
- `servers.lua` — 节点列表（命名段保存）
- `server_list.htm` — 批量选择/删除 UI
- `server_tools.htm` — 导入工具 UI
- `import-ss-txt.sh` — 节点导入脚本（SS + Trojan 支持）
- `build-full-package-from-upstream.ps1` — 构建脚本（安装容错、配置默认值）
