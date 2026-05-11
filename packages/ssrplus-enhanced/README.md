# ShadowsocksR Plus Enhanced

Enhanced ShadowsocksR Plus package sources for GL.iNet/OpenWrt-style routers.

## Included Work

- LuCI status and server list UI improvements
- async apply/rebuild actions
- safer restart and hard-clean actions
- TXT-based SS import helpers
- auto-switch tuning and state reporting
- IPv6 mode control with safe defaults
- full `.run` package build scripts

## Primary Build Scripts

- **`build-full-package-from-upstream.ps1`** — **完整安装包**（约 50MB+）：解压上游 `.run`（含 `luci-app-ssr-plus` ipk、`depends` 等），再合并本仓库增强文件，输出文件名含 **`enhanced_full`**。给新机 / iStore「整包安装」用。
- **`build-release-package.ps1`** — **轻量覆盖包**（约几十 KB）：只含 LuCI / `sync-apply.lua` / init / `ssr-rules` 等脚本，**不含 ipk**；输出文件名含 **`enhanced_overlay`**。仅适用于路由器 **已经安装过** 官方或上游 SSR+、只需打增强补丁的场景。

## Runtime Files Often Touched

- `shadowsocksr.lua`
- `sync-apply.lua`
- `status.htm`
- `server_list.htm`
- `client.lua`
- `servers.lua`

## Notes

This folder contains source and packaging assets for the enhanced ShadowsocksR Plus package. Large binary release artifacts should be attached to GitHub Releases instead of being committed into git history.
