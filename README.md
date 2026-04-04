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
- [Releases](https://github.com/LanceLeeA/router-plugin-hub/releases)
- [Release Notes](https://github.com/LanceLeeA/router-plugin-hub/tree/main/docs/releases)

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
  - reserved for future OpenClash enhancement work

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
- Recommended distribution: attach to GitHub Releases

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
