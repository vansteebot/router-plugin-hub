# SSR Plus+ Enhanced — 20260511

## 修复

- **节点域名解析（切换节点后谷歌等打不开）**
  - `sync-apply.lua` 中 `resolve_ipv4_stable`：去掉向 **`127.0.0.1`** 查询节点域名的后备逻辑；在 SSR 已运行时，本机 DNS 常经 dnsmasq/ChinadNS，对外国 VPS 主机名易产生 **DNS 污染**，错误 IP 被写入 UCI 的 `ip`，代理连错地址（典型表现：**第一次选节点正常，换节点后异常**）。
  - 将 **`http://119.29.29.29/d?dn=`** HTTP DNS 提前到 **`resolveip` 之前**，降低走系统 resolv.conf（多指向本机）时的污染风险。
  - `shadowsocksr.init.remote.sh` 中 `get_host_ip`：与上保持一致的解析顺序与注释说明。

## 安装包

- 文件名：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260511.run`
- 构建目录：`packages/ssrplus-enhanced/release/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260511/`
- SHA256：`28feb7292556a1cba898bba88a6b67755f2664f10aa9dc859250c7321defa27c`（同目录 `SHA256SUMS.txt`）。
