# SSR Plus+ Enhanced — 20260427

## 版本信息

- 版本：20260427(v4.1,在 20260426 基础上的紧急修复)
- 平台：GL-BE3600 / aarch64_cortex-a53-190 / OpenWrt r126
- 安装包：`ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260427.run`
- 大小：~52 MB
- SHA256：`7bd0a24a2b95733b46c073dd1547a81668718e31e2c7e58b22a57fc9c14e5a45`

## 关键修复

### 🚑 修复 LuCI 服务页 500 错误：CRLF 行尾导致模板 parser 崩溃

**症状**(在 20260426 v4 上首次暴露):

访问 `http://192.168.8.1/cgi-bin/luci/admin/services/shadowsocksr` 直接 500:

```
Runtime error
/usr/lib/lua/luci/template.lua:158: Failed to load template 'shadowsocksr/status'.
Error while parsing template '/usr/lib/lua/luci/view/shadowsocksr/status.htm':
Syntax error in /usr/lib/lua/luci/view/shadowsocksr/status.htm:1: unfinished string near '"<script type="text/javascript">//<![CDATA['
```

**根因**:

LuCI 的 C 实现模板 parser(`luci.template.parser`)在编译以 HTML 起头(没有 `<%...%>` 块开头)且**行尾是 CRLF (`\r\n`)** 的 `.htm` 时,把 HTML 文本编译成 Lua 字符串字面量时,会因为 CR 字符干扰转义,生成形如:

```lua
write("<script type="text/javascript">//<![CDATA[
```

引号未转义,Lua 编译报 `unfinished string`。同样的内容只要把 `\r\n` 改成 `\n` 就能正常 parse。

**复现**(隔离测试):

```lua
local p = require 'luci.template.parser'
p.parse_string('<script type="text/javascript">\r\n<%=foo%>')
-- => Syntax error in [string]:1: unfinished string near '"<script type="text/javascript">'

p.parse_string('<script type="text/javascript">\n<%=foo%>')
-- => OK
```

**为什么 v4 之前没爆**:

之前所有版本的 build 用 `Copy-Item` 直接拷贝 Windows 编辑器写入的 .htm 源文件(全 CRLF)。但路由器上其实大部分用户从来没访问过 SSR 服务页(只用 GL.iNet 自家界面),所以这个 bug 一直潜伏。v4 安装时由于内存修复有人去主动验证就触发了。

**修复**(双重):

1. **build 层**(`build-full-package-from-upstream.ps1`):新增 `Copy-TextFile-Lf`,在把 overlay 文件复制到 packageRoot 时,统一 strip BOM 并把 CRLF 转为 LF。所有 18 个 overlay 文件(5 个 .htm + 7 个 .lua + 5 个 .sh + 1 个 .ps1)在打包时都会 normalize。
2. **运行时**(对已安装老版本的临时修复 — 在路由器上执行一次即可):
   ```sh
   cd /usr/lib/lua/luci/view/shadowsocksr/
   for f in *.htm; do sed -i 's/\r$//' "$f"; done
   rm -rf /tmp/luci-modulecache /tmp/luci-indexcache* 2>/dev/null
   /etc/init.d/uhttpd restart
   ```

**实测验证**(GL-BE3600 全新装一次 v4.1):

```
CR-bearing .htm files: (none)
parse check:
  status.htm:        OK
  server_list.htm:   OK
  server_tools.htm:  OK
  status_bottom.htm: OK
  ping.htm:          OK
LuCI page: HTTP 200, 66610 bytes — renders cleanly (no errors)
/tmp leftover ssrplus-enhanced-*: (none) — OK
```

## 同时携带的修复(继承自 20260426)

- 自解压 stub 不再用 `exec`,EXIT trap 正常清理 `/tmp/ssrplus-enhanced-XXXXX/`
- `install.sh` 末尾追加历史残留清理,升级时一并扫掉 pre-v4 残留

## 用户升级

任何安装过任意版本(尤其是 20260426 的)用户,跑一次 v4.1 的 .run 即可:

```sh
wget -O /tmp/ssrp.run https://github.com/vansteebot/router-plugin-hub/releases/download/ssrplus-enhanced-20260427/ssrp_aarch64_cortex-a53-190_r126_enhanced_full_20260427.run
chmod +x /tmp/ssrp.run && /tmp/ssrp.run
```

升级后 LuCI 服务页可正常打开,`/tmp` 不再积累残留。

## 修改文件

- `packages/ssrplus-enhanced/build-full-package-from-upstream.ps1` — 新增 `Copy-TextFile-Lf`,所有 overlay 文件强制 LF 行尾 + 去 BOM
