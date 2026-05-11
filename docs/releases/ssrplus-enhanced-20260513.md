# SSR Plus+ Enhanced — 20260513

## 关键修复 — ChinaDNS-NG UDP 上游被 GFW DNS 抢答投毒

### 症状（极具迷惑性）

- 切换到 **HK 节点**后,**ChatGPT 能访问**(因为在「强制走代理」列表里走 nftset),但 **Google / YouTube / googlevideo.com 等打不开**
- 状态页正确显示「代理出口 IP = HK」,节点探测正常,代理本身完全好
- 路由器 curl 测试:**主域名 `google.com` / `gstatic.com` 解析正常**,但 **`www.google.com` 返回 Twitter IP**、**`www.youtube.com` / `googlevideo.com` 返回 Facebook IP**
- 切其他境外节点(JP/US/SGP/TW)有时正常有时也中招,**间歇性不稳**

### 根因

`/etc/init.d/shadowsocksr` 启动 `chinadns-ng` 时,trusted upstream(用于解析 GFW 域名的境外 DNS)使用了**默认 UDP 模式**:

```
chinadns-ng -b 127.0.0.1 -l ... -p 3 -d gfw -t 1.1.1.1#53 -N --filter-qtype 64,65 ...
                                                ^^^^^^^^^^^ UDP, port 53
```

GFW 对出境 UDP 53 包做深包检测,看到域名匹配黑名单时**抢先**伪造响应包发回路由器(IP 通常是 Facebook/Twitter),压在真正的 1.1.1.1 应答之前到达。chinadns-ng 收下伪造响应并缓存,后续查询都用错的 IP。

主域名 `google.com` 这种"二级"通常**没被抢答**,所以路由器自检 IP 看起来"正常";但浏览器实际访问 `www.google.com` 会触发投毒。这就是为什么"切了 HK 节点连不上 Google 但状态页又说 OK"。

### 修复

- **`shadowsocksr.init.remote.sh`**:当 `uci get global.chinadns_ng_proto` 为空时,**默认值改为 `tcp`**(原本默认是 UDP)。这让 chinadns-ng 用 `-t tcp://1.1.1.1#53`,TCP 流上 GFW 无法抢答。
- **`build-full-package-from-upstream.ps1` / `build-release-package.ps1`**:安装时无条件 `uci set chinadns_ng_proto='tcp'`,确保**已经装过 SSR+ 的用户**升级后也立即切换到 TCP(否则他们的 uci 已经有旧值,init 脚本里的"空则默认 tcp"分支不会触发)。

### 留给用户的选择

如果你确实需要 UDP(比如内网调试,或者你的运营商 TCP 53 被限速更严),仍然可以手动 `uci set shadowsocksr.@global[0].chinadns_ng_proto='none'` 显式覆盖。`'tcp'` 只是新的合理默认值,不是强制锁定。

### 顺带保留:20260512 的 TCP REDIRECT 持久化校验

本次完整包同样包含 20260512 的修复(`ssr-rules` 重启时校验 nftables 持久化文件、cron 守护清理半残文件),不需要单独装老版本。

## 验证

装完后,在路由器终端跑:

```sh
# 1. 校验 chinadns-ng 当前用 TCP
pgrep -af chinadns-ng | grep -q 'tcp://' && echo TCP_MODE_OK || echo STILL_UDP

# 2. 解析 GFW 域名,应该返回真 Google IP(142.250.x / 142.251.x / 172.217.x 等),
#    不应该是 Twitter (104.244.42.x) 或 Facebook (157.240.x / 69.171.x / 69.63.x)
for d in www.google.com www.youtube.com googlevideo.com gstatic.com; do
    printf "%-25s " "$d"
    nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address[: ]/ {a=$NF} END {print a}'
done

# 3. 切到 HK 节点后,curl 应该走代理返回 HK IP 并且 Google 通
curl -4 -m 10 -s https://api.ip.sb/ip          # 应是 HK IP
curl -4 -m 10 -o /dev/null -w '%{http_code}\n' https://www.google.com/generate_204   # 应是 204
```

## 安装包（完整合并包）

- 使用 **`build-full-package-from-upstream.ps1`** 生成,含上游 ipk + 本仓库增强层 + 20260512 TCP 持久化校验 + 本次 ChinaDNS TCP 默认。体积约 **52MB**。
- 文件名:`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260513.run`
- 构建目录:`packages/ssrplus-enhanced/release/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260513/`
- SHA256:见同目录 `SHA256SUMS.txt`
- 已替代 `ssrplus-enhanced-20260512`,本完整包包含其全部修复。

## 仍未解决

- **「保存并应用」按钮卡死等很久**:`sync-apply.lua` 在 IP 检测阶段最坏会卡 ~90 秒(`get_public_ip` 4 次重试 × 3 个 endpoint × 8s timeout)。锁机制 `acquire_lock` 也没有 stale 超时。如果用户在锁未释放前点保存,会看到"后台生效任务正在运行,按钮已锁定"。下一版本修。
- **状态文件 phase 与 ip 字段不一致**:早期 DNS 检测失败时 phase 会停在 `dns` 报错,但后续 IP 检测成功后 `ip` 字段被更新,UI 显示「绿色 IP + 红色 ok=false」混合状态。下一版本修。
