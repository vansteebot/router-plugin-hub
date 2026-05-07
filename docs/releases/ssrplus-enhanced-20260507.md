# SSR Plus+ Enhanced — 20260507

## 版本信息

- 版本：20260507
- 平台：GL-BE3600 / aarch64_cortex-a53-190 / OpenWrt r126
- 安装包：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260507.run`

## 关键修复

### 1) 修复节点切换偶发卡 busy、需要多次闪烁才能生效

根因是并发任务竞争：

- `/etc/init.d/shadowsocksr` 使用 `flock -xn 1000`，在 BusyBox ash 下会触发 `Bad file descriptor`，锁失效。
- 并发重启时，`gfw2ipset.sh` 写入 dnsmasq 临时目录与清理流程互相打架，出现
  `...dnsmasq-ssrplus.d/... No such file or directory`，导致切换链路抖动。

修复：

- 将 `shadowsocksr` init 锁 fd 从 `1000` 改为 `9`。
- 在 `start_rules()` 调用 `gfw2ipset.sh` 前强制 `mkdir -p "$TMP_DNSMASQ_PATH"`。
- `sync-apply.lua` 改为 `mkdir` 原子锁目录（`/var/lock/ssrplus-sync-apply.lock.d`）+ 僵尸锁清理，避免重复点击触发并发任务。

### 2) 新增单节点点击测速（不必每次批量测速）

在服务器列表页支持直接点击“未测速/延迟值”触发该节点测速：

- 后台生效中（busy）会自动禁点并提示等待。
- 批量测速进行中会提示先停止批量再做单点测速。

涉及文件：

- `server_list.htm`
- `ping.htm`

## 风险与兼容性

- 不改变节点协议参数映射逻辑（VLESS/Xray 配置生成规则不变）。
- 仅增强任务锁与前端交互，兼容已有配置。

