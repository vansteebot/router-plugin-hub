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

- `build-full-package-from-upstream.ps1`
- `build-release-package.ps1`

## Runtime Files Often Touched

- `shadowsocksr.lua`
- `sync-apply.lua`
- `status.htm`
- `server_list.htm`
- `client.lua`
- `servers.lua`

## Notes

This folder contains source and packaging assets for the enhanced ShadowsocksR Plus package. Large binary release artifacts should be attached to GitHub Releases instead of being committed into git history.
