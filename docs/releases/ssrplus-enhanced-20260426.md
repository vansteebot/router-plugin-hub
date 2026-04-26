# SSR Plus+ Enhanced — 20260426

## 版本信息

- 版本：20260426
- 平台：GL-BE3600 / aarch64_cortex-a53-190 / OpenWrt r126
- 安装包：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260426.run`
- 大小：~52 MB
- SHA256：`86d6bfce30b275cb0717de1e6d74943168854f969896ebfc75ce2f11026ad527`

## 关键修复

### 🚨 修复安装器 `/tmp` 内存泄漏（每次装漏 53 MB）

**问题**：每装一次 `.run` 包，路由器 `/tmp`（tmpfs，吃物理内存）就会留下一个 `ssrplus-enhanced-XXXXX/` 目录（约 53 MB），永不清理。装 7 次以后 `/tmp` 占用 ~374 MB，触发 OOM Killer，频繁杀掉 `nginx`、`dnsmasq`，最终导致 `http://192.168.8.1/` 无法访问、DNS 间歇性失败、整网卡顿。

**根因**（在 `build-full-package-from-upstream.ps1` 生成的 makeself 自解压头里）：

```sh
# 老代码（pre-v4，BUG）
cd "$WORKDIR"
exec ./install.sh "$@"   # exec 替换当前进程，trap cleanup EXIT 永远不会触发
```

`trap cleanup EXIT` 注册的清理函数（`rm -rf "$WORKDIR"`）在 `exec` 之后随原 shell 进程一起被替换掉，导致 install.sh 退出时 WORKDIR 不会被清理。

**修复**（双重保险）：

1. **去掉 `exec`**：让 `install.sh` 作为子进程运行，原 shell 退出时 trap 正常触发：

   ```sh
   # 新代码 (v4)
   cd "$WORKDIR"
   rc=0
   ./install.sh "$@" || rc=$?
   cd /
   exit $rc
   ```

2. **在 `install.sh` 末尾追加历史残留清理**：升级到 v4 时,前面所有版本积累的 `ssrplus-enhanced-*` 目录会被一次性清掉(向下兼容):

   ```sh
   for d in "$TMPROOT"/ssrplus-enhanced-*; do
     [ -d "$d" ] || continue
     case "$d" in "$CURRENT_PKG_DIR") continue ;; esac
     rm -rf "$d" 2>/dev/null || true
   done
   rm -f "$TMPROOT/ssrp_enhanced.run" 2>/dev/null || true
   ```

**验证结果**（在 GL-BE3600 实测）：

| 指标 | v3 (前) | v4 (后) |
|------|---------|---------|
| 单次安装后 `/tmp` 增量 | **+53 MB** | **+0 MB** ✓ |
| 7 次安装后 `/tmp` 占用 | ~374 MB | ~0 MB |
| 安装后 `ssrplus-enhanced-*` 残留 | 累积 7 个 | 0 个 ✓ |

## 受益用户

如果你遇到下面任一现象,**强烈建议升级**:

- `http://192.168.8.1/` 偶尔打不开,要重启路由器
- `free -m` 显示 `shared` 列异常高(>200 MB)
- DNS 偶发解析失败、整网卡顿
- `dmesg` 看到 OOM Killer 杀 nginx / dnsmasq

升级方法和正常安装一致 —— 跑一次 v4 的 `.run`,旧残留会被自动一并清理。

## 修改文件

- `packages/ssrplus-enhanced/build-full-package-from-upstream.ps1` — makeself stub 去掉 `exec`,install.sh 末尾追加历史残留清理

## 提交记录

| 提交 | 说明 |
|------|------|
| `<待补>` | fix: prevent /tmp memory leak in self-extracting installer |
