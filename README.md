# Router Plugin Hub

Router-side plugin source, packaging scripts, release notes, and installable artifacts.

This repository is intended to be the umbrella home for:

- `SSR Plus+` enhanced builds
- future `OpenClash` enhancements
- router helper scripts, release metadata, and packaging workflows

## Structure

- `packages/ssrplus-enhanced`
  Source, LuCI templates, runtime helpers, packaging scripts, and verification tools for the enhanced SSR Plus+ build.
- `packages/openclash-enhanced`
  Reserved for future OpenClash-related customization work.
- `docs/releases`
  Human-readable release notes and package summaries.

## Release Workflow

1. Make changes inside a package folder.
2. Build a full `.run` installer from the package scripts.
3. Record the release in `docs/releases`.
4. Upload the generated installer to GitHub Releases.

## Current Maintained Package

The currently maintained package is:

- `packages/ssrplus-enhanced`

## Latest Known Full Installer

- Package: `ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260404v4.run`
- Size: about `54.37 MB`
- Notes: includes SSR Plus+ UI enhancements, async apply flow, safer restart controls, auto-switch tuning, and IPv6 mode control with safe defaults.
