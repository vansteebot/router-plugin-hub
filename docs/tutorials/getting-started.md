# 全新手完整教程:从开箱到代理生效绿灯

> 这份教程面向**刚买回 GL.iNet 路由器、之前没碰过 OpenWrt / iStore 的人**。一路照抄命令,大概 60~90 分钟就能完成:激活路由器 → 给原厂固件叠加 iStore 商店 → 装本仓库的 SSR Plus+ Enhanced → 开启 4 条防 WebRTC / QUIC 泄漏规则 → 在 https://webrtcleakshield.org/ 验证真实 IP 不再暴露。
>
> 对应的 release:[v20260618a](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a)。

---

## 目录

1. [适用范围(先看你的路由器在不在表里)](#1-适用范围)
2. [准备清单](#2-准备清单)
3. [第一步 · 开箱激活](#3-第一步--开箱激活)
4. [第二步 · 启用 SSH](#4-第二步--启用-ssh)
5. [第三步 · 给原厂固件叠加 iStore 商店(一键命令)](#5-第三步--给原厂固件叠加-istore-商店一键命令)
6. [第四步 · 进入 LuCI 高级界面](#6-第四步--进入-luci-高级界面)
7. [第五步 · 安装 SSR Plus+ Enhanced(.run)](#7-第五步--安装-ssr-plus-enhancedrun)
8. [第六步 · 添加你的代理节点](#8-第六步--添加你的代理节点)
9. [第七步 · 4 条防火墙规则杜绝 WebRTC / QUIC 泄漏](#9-第七步--4-条防火墙规则杜绝-webrtc--quic-泄漏)
10. [第八步 · 验证:看绿灯 + WebRTC 检测](#10-第八步--验证看绿灯--webrtc-检测)
11. [故障排查 FAQ](#11-故障排查-faq)
12. [卸载 / 回滚](#12-卸载--回滚)
13. [致谢](#13-致谢)

---

## 1. 适用范围

**支持的路由器**:GL.iNet ARM64 系列 — 也就是高通/联发科 ARMv8 芯片的那一批:

| 型号 | 别名 | 一键脚本(下文第 5 步) |
|---|---|---|
| GL-BE3600 | Beryl AX Pro / Wi-Fi 7 | `be3600.sh` |
| GL-BE6500 | Flint 3 / Wi-Fi 7 | `be6500.sh`(BE9300 也用这个) |
| GL-BE9300 | Flint 3 Pro / Wi-Fi 7 | `be6500.sh`(推荐)或独立 `be9300.sh` |
| GL-MT3000 | Beryl AX / Wi-Fi 6 | `gl-inet.sh`(非 OP24)或 `gl-inet-op24.sh`(OP24 固件) |
| GL-MT6000 | Flint 2 / Wi-Fi 6 | `gl-inet-op24.sh`(OP24)或自动检测 `main.sh` |
| GL-MT3600BE | Beryl 7 / Wi-Fi 7 | `mt3600.sh` |
| GL-E5800 | Mudi 7(移动办公) | `mt3600.sh` |
| GL-MT5000 | 三个 2.5G 有线口 | `mt5000.sh` |
| GL-MT2500A | 旅行路由 | 仅自动检测 `main.sh` |
| 不确定 | — | `main.sh`(会自动识别) |

> ⚠️ **不在表里的路由器请勿照抄本教程**。本仓库当前的 `.run` 安装包**仅针对 `aarch64_cortex-a53 / OpenWrt r126`**(实测设备 GL-BE3600)。MIPS 系列(GL-MT300N、GL-AR750)、x86 软路由、其它 ARM 平台,请用 `packages/ssrplus-enhanced/` 源码 + 自家上游 ipk + `build-full-package-from-upstream.ps1` 重新打包后再装。

---

## 2. 准备清单

| 物品 | 说明 |
|---|---|
| ✅ 一台支持的 GL.iNet 路由器 | 见上表 |
| ✅ 一根网线 | 任意普通五类线 |
| ✅ 一台电脑(或手机) | Windows / macOS / Linux 都行,要能开 SSH 终端 |
| ✅ 自己的代理节点账号 | SS / SSR / V2Ray / Trojan / Hysteria2 / TUIC 任意 |
| ✅ WAN 端能上网 | 光猫拨号 / DHCP / 静态 IP 都可 |
| ✅ 能访问 GitHub 和 `cafe.cpolar.cn` | 第 5 步会从 cafe.cpolar.cn 拉一键脚本;第 7 步会从 GitHub Releases 拉 `.run`。如有困难看第 5 / 7 步的"网络受限"分支 |

---

## 3. 第一步 · 开箱激活

1. 接好电源,接好 WAN 网线(从光猫或上级路由出)。等指示灯稳定(约 1 分钟)。
2. 用电脑/手机连无线 `GL-XXXX-xxx`(SSID 在机器底部贴纸,默认无密码或在贴纸上)。或者用网线连任意 LAN 口。
3. 浏览器打开 **<http://192.168.8.1>**(GL.iNet 出厂 IP)。
4. 跟着向导走:
   - 选语言、时区
   - **设置 root 密码(请用强密码,后面 SSH / LuCI 都会用)**
   - WAN 接入方式:
     - 光猫已经做了路由 → 选 **DHCP**(自动获取)
     - 光猫桥接,要在路由器拨号 → 选 **PPPoE**,填运营商账号密码
5. 完成后右上角"互联网状态"应该是绿色。这一步**确保路由器能正常上网**。

---

## 4. 第二步 · 启用 SSH

GL.iNet 出厂默认没开 SSH。一次性打开它,后面的所有命令操作就靠这一个通道。

- GL.iNet 后台(<http://192.168.8.1>)→ **应用 → 高级设置 → 启用 SSH 访问**
- 端口默认 `22`,LAN 网段允许访问
- 用你刚设好的 root 密码

然后在电脑上测试连通:

```bash
ssh root@192.168.8.1
# 第一次会提示验证 host key,输入 yes
# 接着输入你的 root 密码,看到 root@GL-XXXX:~# 提示符就成
```

> 遇到 `Host key verification failed` 是因为以前连过其它 192.168.8.1 设备,本地保存了旧 host key。清掉就好:
> ```bash
> ssh-keygen -R 192.168.8.1
> ```

---

## 5. 第三步 · 给原厂固件叠加 iStore 商店(一键命令)

### 🔍 这一步**不刷机**,先讲清楚

这一步**没有重新刷固件**。GL.iNet 原厂的 UI(<http://192.168.8.1>)、原厂的所有设置都保留不动。我们只是在它运行的 OpenWrt 之上额外装一个 LuCI iStoreOS 风格主题 + iStore 应用商店 + 一些常用包。装完后:

- 原 GL.iNet 简易 UI:仍在 `http://192.168.8.1`
- 新的 LuCI 高级 UI(iStoreOS 风格):在 `http://192.168.8.1:8080`
- iStore 应用商店:在 LuCI 左侧菜单里

任何时候都可以**通过 GL.iNet 后台"恢复出厂设置"清除所有装的东西**,不会变砖。

### 一键命令(根据你的机型选一条)

**对应 GL-BE3600(本教程主测设备)**:

```sh
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/be3600.sh)"
```

**对应其它机型**(SSH 进路由器后执行,**机型不对会一直报错装不上**):

```sh
# 自动检测机型(不确定时用这个,会识别后自动调用对应脚本)
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/main.sh)"

# GL-MT3000(原厂固件,非 OP24)
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/gl-inet.sh)"

# GL-MT3000 / GL-MT6000(OP24 固件,例如 4.8.3-op24)
# ⚠️ OP24 用户先看下面的"OP24 前置步骤"
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/gl-inet-op24.sh)"

# GL-BE6500 / GL-BE9300(BE9300 推荐用这条)
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/be6500.sh)"

# GL-MT3600BE / GL-E5800 Mudi 7
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/mt3600.sh)"

# GL-MT5000(三个 2.5G 有线口)
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/mt5000.sh)"
```

执行后命令行会自动 `opkg update` → 装 iStore → 装 LuCI 主题 → 套用 iStoreOS 风格。**整个过程 3~10 分钟**(看你的网络速度),期间**不要断电不要重启**。结束时大概率会自动 reboot,如果没有,等命令返回后手动 `reboot` 一次。

### 📜 OP24 前置步骤(只有 MT3000 / MT6000 的 OP24 固件需要)

OP24 固件在国内拉 OpenWrt 官方源很慢甚至超时。**在跑 `gl-inet-op24.sh` 之前**,先在 LuCI(临时用 GL.iNet 后台进入)→ **系统 → 软件包 → 配置 OPKG**,把 `/etc/opkg/distfeeds.conf` 替换成阿里云镜像源(具体行参见 wukongdaily 项目 README)。

如果你跳过这一步,装的时候可能挂在 "downloading ..." 几十分钟没反应。

### 🌐 网络受限场景(路由器拉不到 cafe.cpolar.cn)

如果路由器在出口被拦着,或者根本上不了 `cafe.cpolar.cn`,wukongdaily 项目提供了**内网镜像方案**(在你局域网另一台机器跑 docker 镜像,然后路由器从内网拉):

1. 在局域网另一台能上 Docker Hub 的电脑跑:
   ```bash
   docker run -d --restart unless-stopped --name glibox -p 15050:15050 wukongdaily/glibox
   ```
2. 在路由器 SSH 里:
   ```sh
   read -p "请输入 glibox 局域网 IP: " ip && \
     wget -O /tmp/gl.sh http://$ip:15050/glinet/be3600.sh && \
     sh /tmp/gl.sh $ip
   ```
   `be3600.sh` 替换成你机型对应的脚本名(同上表)。

### 📜 致谢与版权说明

> 上面这些"一键命令"来自 [**wukongdaily/gl-inet-onescript**](https://github.com/wukongdaily/gl-inet-onescript)(GPL-3.0)。
>
> 本教程**只引用 `curl | sh` 这一行调用**,**没有修改也没有重新分发它的脚本本体**,脚本所有权与维护权归原作者 wukongdaily 所有。如果你觉得这个项目有用,可以去他的仓库 ⭐ Star、看他的 B 站 / YouTube 视频、给他买杯咖啡。本仓库只是利用这一行命令把你的路由器调到一个"有 iStore 商店、有 LuCI 高级界面"的状态,**接下来第 7 步起的所有内容才是本仓库自己的工作**。

---

## 6. 第四步 · 进入 LuCI 高级界面

装完后(重启完成后),浏览器打开:

| 入口 | 地址 | 用途 |
|---|---|---|
| **LuCI(iStoreOS 风格,高级)** | <http://192.168.8.1:8080> | 安装插件、配置防火墙、看日志、运行 SSR Plus+ |
| GL.iNet 简易后台 | <http://192.168.8.1> | 基础联网设置、Wi-Fi 修改、固件升级 |

登录密码是你**第 3 步设的那个 root 密码**(脚本不会改密码)。

> ❓ `http://192.168.8.1:8080` **连接被拒绝**?常见在 4.7.0 之后的固件。等 1~2 分钟让服务起完,或者 SSH 进去看一下:
> ```bash
> ssh root@192.168.8.1 'netstat -lnt | grep :8080'
> ```
> 应该有一行 `LISTEN`。没有的话:`/etc/init.d/uhttpd restart`。

---

## 7. 第五步 · 安装 SSR Plus+ Enhanced(.run)

本仓库的 SSR Plus+ Enhanced 是一个**单文件 `.run` 离线安装包**,内含上游 `luci-app-ssr-plus` 的 `ipk` + 全部 `depends` + 我们的增强 overlay(严格国内分流、UI 永远可点的健康指示、批量节点导入等)。

> 当前 release:**[v20260618a](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a)** · SHA256 `8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e` · 51.86 MB
>
> 直链 `.run`:<https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run>

下面两种方式任选其一。新手推荐方式 A(图形界面)。

### 方式 A · iStore 图形界面上传(推荐新手)

1. **下载 `.run`** 到你电脑:点上面的"直链 `.run`",或者去 [Release 页面](https://github.com/vansteebot/router-plugin-hub/releases/tag/v20260618a) 点 Assets 下载。
2. 浏览器打开 LuCI:<http://192.168.8.1:8080>
3. 左侧菜单 → **iStore** → 顶部 Tab 切换到 **"手动安装"**
4. 找到"**离线安装**"区块:右侧那块蓝色虚线区域 **"选择或拖放文件到此处"** —— 把刚下载的 `.run` 拖进去(或者点击选文件)。
5. 上传完成后会自动开始安装,日志在页面下方实时滚动。
6. **整个过程 30~60 秒**。看到 `[SSRPLUS-INSTALL] Install finished` 字样就成。
7. 安装完成后下面的"**离线安装记录**"会出现新一行,文件名是 `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run`。
8. 浏览器刷新 LuCI → 左侧菜单 → **服务 → ShadowSocksR Plus+** 应该出现了。

> 📷 界面预览(你看到的就该是这样):iStore 顶部 4 个 Tab(已安装 / 全部软件 / **手动安装** / 维护),"手动安装"页面下方有"离线安装"标题 + 蓝色虚线上传区 + "离线安装记录"列表。

### 方式 B · SSH 一行命令(推荐自动化 / 老司机)

```bash
ssh root@192.168.8.1
wget -O /tmp/ssrp-enhanced.run \
  "https://github.com/vansteebot/router-plugin-hub/releases/download/v20260618a/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260618a.run"
echo "8e94bd44504083ebb21e3b4fbb8d0755834b17a18fe986db370c1d1faf9ca00e  /tmp/ssrp-enhanced.run" | sha256sum -c -
sh /tmp/ssrp-enhanced.run
```

第二行的 `sha256sum -c` 是**完整性校验**,正常输出 `/tmp/ssrp-enhanced.run: OK`。不 OK 的话别装,重新下。

> 如果路由器没装 `wget`,换 `curl`:`curl -L -o /tmp/ssrp-enhanced.run "<URL>"`

### 装完后第一眼看什么

LuCI → 服务 → ShadowSocksR Plus+ → **客户端** 页,顶部 4 张卡片:

| 卡片 | 现在显示 | 该是什么 |
|---|---|---|
| 当前节点 | `未选择`(初次) | 装好后还没加节点,正常 |
| 服务器 | `-` | 同上 |
| 当前阶段 | `idle` | 同上 |
| 代理出口 IP | `-` | 同上 |

下方状态条:🔴 **`ShadowsocksR Plus+ 未运行`** — 因为我们还没加节点。下一步加节点。

---

## 8. 第六步 · 添加你的代理节点

两种添加方式,选一个:

### A. 单条添加(最简单,适合 1~2 个节点)

LuCI → 服务 → ShadowSocksR Plus+ → **服务器节点** → 点页面上方的 **"添加"** 按钮:

- **类型**:按你节点的协议选 SS / SSR / V2Ray / Trojan / Hysteria2 / TUIC 之一
- **服务器地址**:节点的域名或 IP
- **端口、加密方法、密码**:从你的节点信息复制
- 其它选项(混淆 / 协议 / TLS / WS 路径等)按节点提供方说明填

填完点 **"保存 & 应用"** → 回到节点列表,新增的一行点最后那个 **"应用"** 按钮 → 等几秒,状态条变绿。

### B. 批量导入(适合一次几十/上百个节点)

如果你有订阅链接或者 `ss://...` / `trojan://...` 的列表:

1. LuCI → 服务 → ShadowSocksR Plus+ → **服务器节点** → 滚到页面下方 **"SS 批量导入"** 区块
2. 三选一来源:
   - **读取路由器文件**:填 `/root/ssrplus-txt`,把 `.txt` 列表通过 scp 传到这个目录
   - **上传 TXT**:直接选本地 `.txt` 文件
   - **粘贴 ss:// 节点**:文本框直接粘贴,每行一条
3. 点 **"批量解析 / 覆盖导入"**,等几秒,节点列表会刷新

导入后回 **客户端** 页,在 **"主服务器"** 下拉里选刚加的那个节点 → 点 **"保存 & 应用"**。

### 验证节点起来了

等 5~15 秒,LuCI 客户端页顶部状态条应该变成 🟢:

> **ShadowsocksR Plus+ 运行中 · 代理出口已生效**

如果是 🟠 `运行中 · 出口仍是直连 IP,代理未生效` —— 大概率节点不通,或者节点本身就在国内。换个节点,或者去服务器节点页 → **"批量测速"** 看延迟。

---

## 9. 第七步 · 4 条防火墙规则杜绝 WebRTC / QUIC 泄漏

### ⚠️ 这一步是大多数 "代理装好了,但还是被网站测到真实位置" 的根因

即使 SSR 工作正常,浏览器(尤其是 Chrome / Edge)在两条路径上**会绕过路由器的 NAT 直接询问外部服务器你的真实 IP**:

| 通道 | 端口 | 后果 |
|---|---|---|
| **WebRTC STUN/TURN** | UDP `3478 3479 5349 5350 19302-19309`,TCP `3478 5349` | 网页的 JS 拿到你的真实公网 IP / 内网 IP |
| **QUIC(HTTP/3)** | UDP `443`、`80` | Chrome 优先用 QUIC 直连,而 ss-redir 默认只接管 TCP 流量,UDP QUIC 整段绕过代理 |

我们在路由器层面**直接 REJECT 这两类流量的 lan → wan 转发**,浏览器会立刻 fallback 到正常 TCP,经过 ss-redir 走代理。

### 4 条规则做什么(对应截图里的 Anti-Leak 1~4)

| 规则名 | 协议 | 端口 | 动作 |
|---|---|---|---|
| Anti-Leak 1: Block QUIC UDP 443 | UDP | 443 | REJECT lan → wan |
| Anti-Leak 2: Block QUIC UDP 80 | UDP | 80 | REJECT lan → wan |
| Anti-Leak 3: Block WebRTC STUN/TURN UDP | UDP | 3478, 3479, 5349, 5350, 19302-19309 | REJECT lan → wan |
| Anti-Leak 4: Block WebRTC STUN/TURN TCP | TCP | 3478, 5349 | REJECT lan → wan |

### 方式 A · 一键脚本(推荐)

SSH 进路由器,跑一行命令(脚本会**自动去掉同名旧规则再加新的**,可以反复跑):

```bash
ssh root@192.168.8.1
wget -O /tmp/anti-leak.sh \
  "https://raw.githubusercontent.com/vansteebot/router-plugin-hub/main/packages/ssrplus-enhanced/anti-leak-firewall.sh"
sh /tmp/anti-leak.sh
```

输出大概长这样:

```
[Anti-Leak] Removing any existing Anti-Leak* rules (idempotent)...
[Anti-Leak] Adding 4 anti-leak rules...
[Anti-Leak]   added: Anti-Leak 1: Block QUIC UDP 443  (udp 443)
[Anti-Leak]   added: Anti-Leak 2: Block QUIC UDP 80   (udp 80)
[Anti-Leak]   added: Anti-Leak 3: Block WebRTC STUN/TURN UDP  (udp 3478 3479 5349 5350 19302-19309)
[Anti-Leak]   added: Anti-Leak 4: Block WebRTC STUN/TURN TCP  (tcp 3478 5349)
[Anti-Leak] Committing UCI + reloading firewall...
[Anti-Leak] Done. ...
```

### 方式 B · LuCI 手动添加(界面操作,更直观)

LuCI → 网络 → 防火墙 → **通信规则** Tab → 拉到底部 → 点 **"添加"**,每条规则按下面填,**填完点保存,4 条都加完后点页面右下 "保存并应用"**:

- 名称:`Anti-Leak 1: Block QUIC UDP 443`
- 协议:`UDP`
- 来源区域:`lan`
- 目标区域:`wan`
- 目标端口:`443`
- 动作:`拒绝(REJECT)`
- IP 族:`IPv4 + IPv6`(any)
- 启用:✅

第 2 条把端口改 `80`,第 3 条把协议改 `UDP` + 端口 `3478 3479 5349 5350 19302-19309`,第 4 条 `TCP` + 端口 `3478 5349`。

### 卸载这 4 条规则

只需要再跑一次 `anti-leak.sh`,它会先删同名规则再加 —— 中途的最后那"再加"那一步不想要的话,SSH 删:

```bash
ssh root@192.168.8.1 'while uci show firewall | grep -q "name=.Anti-Leak"; do
  sect=$(uci show firewall | awk -F"[.=]" "/name=.Anti-Leak/{print \$2; exit}")
  uci delete firewall.$sect
done; uci commit firewall; /etc/init.d/firewall reload'
```

---

## 10. 第八步 · 验证:看绿灯 + WebRTC 检测

走到这里,你已经做完了所有事。最后做两次检验:

### A. LuCI 状态条是否绿灯

浏览器开 LuCI → 服务 → ShadowSocksR Plus+ → 客户端页 → 顶部:

> 🟢 **ShadowsocksR Plus+ 运行中 · 代理出口已生效**

底下 4 张卡片应该都有值,代理出口 IP **不等于** 直连公网 IP。

### B. 浏览器到 https://webrtcleakshield.org/ 自测

打开 <https://webrtcleakshield.org/?utm_source=webrtcleakshield> —— 这是一个 WebRTC 真实 IP 探测页:

| 字段 | 应该 | 不应该 |
|---|---|---|
| **Public IP**(检测页右上 IP 显示) | 你的**代理节点出口 IP**(国外) | 你家的真实公网 IP |
| **WebRTC IP(s)** | 与上面一致,或者显示 `No leak detected` / `blocked` | 你家的真实公网 IP / 内网 192.168.x.x |

如果 WebRTC IP 依然是你家真实 IP,说明第 9 步的规则没生效。SSH 检查:
```bash
ssh root@192.168.8.1 'nft list ruleset | grep -A1 -B1 "Anti-Leak"'
```
应该能看到 4 条 `reject` 规则。看不到的话再跑一次 anti-leak 一键脚本,重试浏览器(**Ctrl+Shift+R 强刷新 + 切到无痕模式**)。

---

## 11. 故障排查 FAQ

### Q1. 第 5 步 `cafe.cpolar.cn` 超时,装不上 iStore 怎么办
路由器拉不到这个域名。两个选项:
- 用第 5 步底部 "网络受限场景" 里的**内网 glibox 镜像方案**(局域网另一台机器跑 docker)
- 临时手机开热点,让路由器先用手机网络跑完一键命令,再切回家里宽带

### Q2. 第 7 步装完了,LuCI 看不到 "服务 → ShadowSocksR Plus+"
LuCI 模板缓存。SSH 进去清:
```bash
ssh root@192.168.8.1 'rm -rf /tmp/luci-modulecache/* /tmp/luci-indexcache; /etc/init.d/uhttpd restart'
```
浏览器 Ctrl+Shift+R 强刷。

### Q3. 状态条一直是 🟠 橙色 "出口仍是直连 IP"
说明 ss-redir 起来了但流量没真的走代理。逐条排查:
1. **客户端**页 "主服务器" 下拉确认选的不是 `停用`
2. **服务器节点** → 点 **"批量测速"** → 看你选中的那个节点延迟列。`未连通` 的换一个
3. SSH 看 `@china` set 加载:`ssh root@192.168.8.1 'nft list set inet ss_spec china | wc -l'` 应该 3500+,如果是 0:`/etc/init.d/shadowsocksr restart`
4. 看 chinadns-ng 进程是否残留:`ssh root@192.168.8.1 'ps w | grep chinadns-ng | grep -v grep | wc -l'` 应该 2,>2 就是有残留:`pkill -9 -f chinadns-ng; /etc/init.d/shadowsocksr restart`

### Q4. 第 9 步装了 anti-leak 规则后,某些视频会议(腾讯会议 / Zoom / Google Meet)用不了
WebRTC 是这些会议系统的底层。两个折中方案:
- 临时关掉 Anti-Leak 3 + Anti-Leak 4(LuCI 防火墙 → 通信规则 → 找到那两条 → 编辑 → 关闭复选框 → 保存并应用)
- 或者在 LuCI → 服务 → ShadowSocksR Plus+ → 访问控制 → **强制走 WAN 列表** 把视频会议域名/IP 加进去(让它直连不走代理也不被 anti-leak 拦)
- 用完会议再开回 Anti-Leak 规则

### Q5. 第 7 步装完后路由器变慢 / 无法上网
SSR Plus+ 默认 `run_mode=router`(国内直连国外走代理)。如果你的国外节点延迟超高或者根本不通,会拖累整个出网。验证:
- 在路由器 SSH 跑:`curl -m 5 -I https://baidu.com`(国内,应该秒回)和 `curl -m 5 -I https://www.google.com`(国外,经代理)
- 第一条慢/失败 → 是国内 DNS 问题,看 Q3
- 第二条慢/失败 → 节点不可用,换节点

### Q6. SSH 第一次连提示 `Host key verification failed`
本地 known_hosts 里有同一 IP 的旧 host key。
```bash
ssh-keygen -R 192.168.8.1
```
再连一次,会问 yes/no,输 yes 就好。

### Q7. 装完 iStore 后,GL.iNet 原后台 (http://192.168.8.1) 还能用吗
**能**。原 UI 不受影响,密码也不变。两个 UI 共存。

---

## 12. 卸载 / 回滚

### 只卸载 SSR Plus+ Enhanced(保留 iStore + 路由功能)

每次安装 `.run` 都会备份到 `/root/ssrplus-enhanced-install-backup-<时间戳>/`,目录结构镜像原路径。回滚到任一备份:

```bash
ssh root@192.168.8.1
ls /root/ | grep ssrplus-enhanced-install-backup     # 找你想回到的那个时间戳
BAK=/root/ssrplus-enhanced-install-backup-XXXXXXXX-XXXXXX
cd "$BAK" && find . -type f | while read f; do
  cp -a "$f" "/${f#./}"
done
rm -rf /tmp/luci-*cache; /etc/init.d/uhttpd reload
```

完全卸载 SSR Plus+(连上游 ipk 一起):

```bash
ssh root@192.168.8.1
opkg remove --autoremove luci-app-ssr-plus shadowsocksr-libev-ssr-redir shadowsocksr-libev-ssr-local 2>/dev/null
rm -rf /etc/config/shadowsocksr /etc/ssrplus /usr/share/shadowsocksr /var/etc/ssrplus
rm -f /etc/init.d/shadowsocksr /usr/bin/ssr-switch /usr/bin/ssr-rules
/etc/init.d/uhttpd reload
```

### 把整个路由器恢复出厂(全清,回到第 3 步状态)

GL.iNet 后台 → **系统 → 还原 / 恢复出厂** → 走流程。或者 SSH:
```bash
ssh root@192.168.8.1 'firstboot && reboot'
```

恢复出厂后:iStore 主题、本仓库的 SSR 全部消失,Wi-Fi 名/密码、所有节点、所有防火墙规则全部清空,**会断网**,过一两分钟路由器重启完用 `192.168.8.1` 重新做第 3 步。

---

## 13. 致谢

| 项目 | License | 致谢点 |
|---|---|---|
| [wukongdaily/gl-inet-onescript](https://github.com/wukongdaily/gl-inet-onescript) | GPL-3.0 | 第 5 步的一键命令直接引用了他的脚本 URL,所有 iStoreOS 风格化的工作都是他做的。本仓库只做了"引用 + 接续我们的 SSR Plus+ 安装" |
| [fw876/helloworld](https://github.com/fw876/helloworld) | GPL-3.0 | 上游 `luci-app-ssr-plus`,本仓库的 SSR Plus+ Enhanced 是基于它的增强 overlay |
| OpenWrt | GPL-2.0 | 路由器操作系统底座 |
| iStoreOS | GPL-3.0 | LuCI 风格 / iStore 应用商店 |

本教程内的所有原创内容(SSR `.run` 链接、anti-leak 防火墙脚本、UI 走查、故障排查 FAQ)归本仓库 vansteebot/router-plugin-hub 维护,遵循同样的开源协议链路。如发现教程有错或想加东西,欢迎 [提 Issue](https://github.com/vansteebot/router-plugin-hub/issues)。
