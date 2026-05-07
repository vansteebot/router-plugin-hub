# SSR Plus+ Enhanced — 20260508

## 修复

- **`gfw2ipset.sh`（仓库：`gfw2ipset.remote.sh`）**
  - 将 `black.list` / `white.list` / `deny.list` 对 `gfw_list.conf` / `gfw_base.conf` 的过滤从「对大文件反复 `sed -i`」改为 **单次 `awk` 扫描输出到临时文件再原子替换**。
  - 背景：`gfw_list.conf` 可达数万行；反复 `sed -i` 在路由器上会 **长时间卡住**（表现为切换节点 `busy` 很久），并在 `/tmp`（tmpfs）上更容易触发 `sed` 临时文件 rename 竞争，进而出现 `gfw_list.conf: No such file or directory` / dnsmasq 读配置失败。

- **`shadowsocksr.lua`（状态接口）**
  - `status_info` 原先仅用 `ss-redir` 判断主代理是否运行；**VLESS/VMess 等节点实际进程多为 `v2ray`/`xray`**，会导致界面误判为「主代理进程未运行」。
  - 现在 `running` 会同时识别常见核心进程：`ss-redir`、`ss-local`、`v2ray`、`xray`、`trojan`、`hysteria`、`naive`。

- **`sync-apply.lua`（后台生效）**
  - `wait_for_processes` 原先只等待 `ss-redir`，切换到 **`type=v2ray`（含 VLESS）** 时会误判为「ss-redir 未成功启动」，状态长期异常或反复重试。
  - 现在按 UCI 节点 `type` 等待对应主进程（`v2ray`/`xray`、`trojan`、`hysteria`、`naive`、`ss-redir`/`ss-local`/`ss-rust`）。
  - **DNS 检测**：原先只认 UCI `pdnsd_enable` 映射的单一进程（例如 `dns2tcp`）；但在 **`run_mode=router`（绕过大陆）** 下，`shadowsocksr` init 会 **额外启动一条 `chinadns-ng` 国内链路**（即便你选择 DNS2TCP 作为“国外 DNS 查询路径”）。切换节点重启时，`dns2tcp` 可能出现 **秒级空窗**，旧逻辑会误报「dns2tcp 未成功启动」并触发 UI `busy/闪烁`。  
    `dns_chain_ready` 的含义是：**仍以你选择的 DNS 模式为主**（优先检测到 `dns2tcp`），但若正处于重启窗口、上游组件短暂缺失而 **`chinadns-ng` 等分流 DNS 仍在**，则不算致命失败——这与固件真实启动顺序一致，**不是忽略你在界面里选的 DNS 解析方式**。
  - **等待超时**：`wait_for_processes` 默认等待由 **25s 提升到 45s**，降低偶发慢重启导致的误判重试。
  - `perform_restart` / 停用清理时的 `killall` 同步补上 `v2ray`、`trojan` 等，避免旧核心残留。

## 备注

- `gfw2ipset` 在大列表下仍可能需要数十秒 CPU 时间（取决于列表规模），但应避免再出现“无限卡住/切换风暴”。
