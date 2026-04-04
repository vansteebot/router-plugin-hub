# Router Plugin Hub

[![Repo](https://img.shields.io/badge/GitHub-router--plugin--hub-181717?logo=github)](https://github.com/LanceLeeA/router-plugin-hub)
[![Platform](https://img.shields.io/badge/Platform-GL.iNet%20%2F%20OpenWrt-4c6ef5)](https://github.com/LanceLeeA/router-plugin-hub)
[![Package](https://img.shields.io/badge/Current-SSR%20Plus%2B%20Enhanced-10b981)](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
[![Releases](https://img.shields.io/badge/Release-GitHub%20Releases-f59e0b)](https://github.com/LanceLeeA/router-plugin-hub/releases)

Router Plugin Hub is a centralized repository for router-side plugin enhancements, packaging workflows, release notes, and installable artifacts.

This repository is the umbrella home for:

- enhanced `SSR Plus+` builds
- future `OpenClash` enhancements
- router troubleshooting and recovery helpers
- release notes, build scripts, and installable `.run` packages

---

## Download and Install

### Latest Release

- Release page: [GitHub Releases](https://github.com/LanceLeeA/router-plugin-hub/releases)
- Current package: [SSR Plus+ Enhanced 20260404v4](https://github.com/LanceLeeA/router-plugin-hub/releases/tag/ssrplus-enhanced-20260404v4)
- Direct installer: [ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run](https://github.com/LanceLeeA/router-plugin-hub/releases/download/ssrplus-enhanced-20260404v4/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run)

### iStore Installation

For compatible soft-router environments:

1. Download the `.run` package from GitHub Releases.
2. Open `iStore` on the router.
3. Upload the `.run` package manually.
4. Install it directly from iStore.

## Preview

### What you get in this package

- A cleaner `ShadowsocksR Plus+` client dashboard with compact status cards
- Async apply / rebuild flows with safer button locking
- Node list helpers, batch latency checks, and controlled auto-switch support
- Full `.run` package release workflow for soft-router / iStore upload installs

### Quick preview links

- [SSR Plus+ package page](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
- [OpenClash package page](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages/openclash-enhanced)
- [Install guide](https://github.com/LanceLeeA/router-plugin-hub/blob/main/docs/install.md)
- [Release notes](https://github.com/LanceLeeA/router-plugin-hub/tree/main/docs/releases)

### 中文预览

- 更紧凑的 `ShadowsocksR Plus+` 客户端状态区
- 更安全的异步保存、生效、重建流程
- 节点列表批量测速与受控自动切换
- 可直接用于软路由 `iStore` 上传安装的完整 `.run` 包

### 中文快速说明

- `.run` 安装包请从 [GitHub Releases](https://github.com/LanceLeeA/router-plugin-hub/releases) 下载
- 对于兼容的软路由环境，可在 `iStore` 中直接上传并安装
- 当前推荐安装包：
  [ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run](https://github.com/LanceLeeA/router-plugin-hub/releases/download/ssrplus-enhanced-20260404v4/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run)

---

## 中文简介

`Router Plugin Hub` 是一个面向路由器插件增强开发的总仓库，用来统一管理插件源码、打包脚本、发布说明和可安装文件。

这个仓库适合持续维护以下内容：

- `SSR Plus+` 增强版
- 未来的 `OpenClash` 增强版
- 路由器排障、恢复、导入导出相关脚本
- GitHub Releases 发布资料与安装包构建流程

---

## Quick Links

- [Repository](https://github.com/LanceLeeA/router-plugin-hub)
- [Packages](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages)
- [ShadowsocksR Plus](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages/ssrplus-enhanced)
- [OpenClash](https://github.com/LanceLeeA/router-plugin-hub/tree/main/packages/openclash-enhanced)
- [Releases](https://github.com/LanceLeeA/router-plugin-hub/releases)
- [Release Notes](https://github.com/LanceLeeA/router-plugin-hub/tree/main/docs/releases)
- [Install Guide](https://github.com/LanceLeeA/router-plugin-hub/blob/main/docs/install.md)

---

## Repository Layout

```text
router-plugin-hub/
├─ packages/
│  ├─ ssrplus-enhanced/
│  └─ openclash-enhanced/
├─ docs/
│  └─ releases/
└─ README.md
```

### Packages

- `packages/ssrplus-enhanced`
  Enhanced SSR Plus+ source, LuCI templates, runtime helpers, packaging scripts, and verification tools.
- `packages/openclash-enhanced`
  Reserved for future OpenClash-related customization work.

### Docs

- `docs/releases`
  Human-readable release notes and GitHub release drafts.

---

## Current Maintained Package

The package currently under active maintenance is:

- `packages/ssrplus-enhanced`

## Package Index

### ShadowsocksR Plus

- Source path: `packages/ssrplus-enhanced`
- Purpose:
  - enhanced LuCI status and control UI
  - safer async apply and restart flow
  - SS import and packaging helpers
  - auto-switch tuning and monitoring
  - IPv6 mode control with safe defaults

### OpenClash

- Source path: `packages/openclash-enhanced`
- Purpose:
  - future OpenClash enhancement modules
  - configuration import/export helpers
  - DNS / IPv6 safety controls
  - packaging and release notes

### Current Focus

The ShadowsocksR Plus enhancement work currently includes:

- improved LuCI status and control UI
- safer async apply and restart flow
- TXT-based `ss://` import tooling
- auto-switch tuning and monitoring
- cleaner recovery controls for unstable proxy states
- IPv6 mode control with safe defaults for proxy environments

---

## Latest Known Full Installer

- Package: `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run`
- Size: about `54.37 MB`
- Type: full upstream-style `.run` package
- Download location: GitHub Releases
- Recommended distribution: attach the `.run` package to GitHub Releases, not to git history

### Where To Download

The `.run` installer should be downloaded from:

- [GitHub Releases](https://github.com/LanceLeeA/router-plugin-hub/releases)

This repository keeps source code, build scripts, and release notes in git.
Large installable `.run` artifacts should be distributed through the Releases page.

### iStore Installation

For soft-router environments, this full `.run` package is intended to be used as a directly installable package through iStore manual upload / installation workflows.

中文说明：

- `.run` 安装包请从 GitHub Releases 下载
- 下载后可在软路由 `iStore` 中直接上传安装
- 仓库本身主要保存源码、打包脚本和发布说明，不建议把大体积 `.run` 文件反复提交到 git 历史中

### Highlights

- enhanced SSR Plus+ UI and controls
- safer async apply flow
- hard cleanup and rebuild actions
- auto-switch tuning
- IPv6 mode control with safe defaults

---

## Release Workflow

1. Make changes inside a package folder.
2. Build a full `.run` installer from the package scripts.
3. Record release notes in `docs/releases`.
4. Upload the installer to GitHub Releases.

### Recommended Rule

Keep source code, scripts, docs, and release notes in git.

Attach large `.run` binaries to GitHub Releases instead of committing them repeatedly into repository history.

---

## Why This Repository Exists

Managing router plugin customization across scattered folders becomes hard to maintain. This repository provides:

- one home for plugin source changes
- one place for release notes and packaging logic
- a clean structure for future expansion beyond SSR Plus+
- a reusable workflow for publishing installable router packages

---

## Planned Expansion

Future work may include:

- OpenClash enhancement modules
- shared router diagnostics helpers
- unified installer and release metadata
- per-package docs and recovery guides

---

## Chinese Quick Summary

如果你是中文用户，可以把这个仓库理解成：

- 一个总分类仓库
- 里面按插件分目录
- 当前重点维护 `SSR Plus+`
- 后续可以继续增加 `OpenClash` 等插件增强内容
- 安装包建议通过 GitHub Releases 发布
