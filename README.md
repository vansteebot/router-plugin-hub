# Router Plugin Hub

Router Plugin Hub is a centralized repository for router-side plugin enhancements, packaging workflows, release notes, and installable artifacts.

This repository is designed to keep custom router plugin work organized in one place, including:

- enhanced `SSR Plus+` builds
- future `OpenClash` enhancements
- helper scripts for router-side troubleshooting and recovery
- release notes, packaging scripts, and GitHub Release assets

---

## 中文简介

`Router Plugin Hub` 是一个面向路由器插件增强开发的总仓库，用来统一管理插件源码、打包脚本、发布说明和可安装文件。

这个仓库的目标是把后续所有和路由器插件相关的工作放到一个清晰的分类结构里，比如：

- `SSR Plus+` 增强版
- 后续的 `OpenClash` 增强版
- 路由器故障排查、恢复、导入导出相关脚本
- 安装包构建流程与 GitHub Releases 发布资料

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
  Source, LuCI templates, runtime helpers, packaging scripts, and verification tools for the enhanced SSR Plus+ build.
- `packages/openclash-enhanced`
  Reserved for future OpenClash-related customization work.

### Docs

- `docs/releases`
  Human-readable release notes and package summaries.

---

## Current Maintained Package

The currently maintained package is:

- `packages/ssrplus-enhanced`

### Current Focus

The SSR Plus+ enhancement work currently covers:

- improved LuCI status and control UI
- safer async apply/restart flow
- TXT-based `ss://` import tooling
- auto-switch tuning and monitoring
- cleaner recovery controls for unstable proxy states
- IPv6 mode control with safe defaults for proxy environments

---

## Release Workflow

1. Make changes inside a package folder.
2. Build a full `.run` installer from the package scripts.
3. Record release notes in `docs/releases`.
4. Upload the generated installer to GitHub Releases.

### Latest Known Full Installer

- Package: `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run`
- Size: about `54.37 MB`
- Notes:
  - full upstream-style `.run` package
  - enhanced SSR Plus+ UI and controls
  - async apply flow and safer restart behavior
  - auto-switch tuning
  - IPv6 mode control with safe defaults

---

## Why This Repository Exists

Managing router plugin customization across multiple ad hoc folders becomes hard to maintain over time. This repository provides:

- one home for plugin source changes
- one place for release notes and packaging logic
- a clean structure for future expansion beyond SSR Plus+
- a reusable workflow for publishing installable router packages

---

## Planned Expansion

Future work may include:

- OpenClash enhancement modules
- shared router diagnostics helpers
- unified installer/release metadata
- per-package docs and recovery guides

---

## Notes

- Large binary installers should preferably be attached to GitHub Releases instead of committed repeatedly into git history.
- Source code, packaging scripts, release notes, and documentation should remain in the repository.

---

## Chinese Quick Summary

如果你是中文用户，可以把这个仓库理解成：

- 一个总分类仓库
- 里面按插件分目录
- 当前重点维护 `SSR Plus+`
- 后续可以继续增加 `OpenClash` 等插件增强内容
- 安装包建议通过 GitHub Releases 发布
