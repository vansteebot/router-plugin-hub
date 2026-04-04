# Release Process

## English

This repository uses GitHub Releases to distribute full `.run` installer packages.

### Recommended Flow

1. Update package source under `packages/`.
2. Build the full installer package.
3. Update release notes in `docs/releases/`.
4. Publish a GitHub Release and upload:
   - `.run` installer
   - `SHA256SUMS.txt`
   - release `README.md` if needed

### Release Script

Use:

```bash
python scripts/publish_github_release.py \
  --owner LanceLeeA \
  --repo router-plugin-hub \
  --tag ssrplus-enhanced-20260404v4 \
  --title "SSR Plus+ Enhanced 20260404v4" \
  --body-file docs/releases/ssrplus-enhanced-20260404v4-release-draft.md \
  --asset "C:/path/to/package.run" \
  --asset "C:/path/to/SHA256SUMS.txt" \
  --asset "C:/path/to/README.md"
```

Set `GITHUB_TOKEN` before running the script.

---

## 中文

本仓库通过 GitHub Releases 分发完整 `.run` 安装包。

### 推荐发布流程

1. 修改 `packages/` 下的插件源码。
2. 构建完整安装包。
3. 更新 `docs/releases/` 中的发布说明。
4. 创建 GitHub Release，并上传：
   - `.run` 安装包
   - `SHA256SUMS.txt`
   - 如有需要可附带发布版 `README.md`

### 发布脚本

可使用以下脚本发布：

```bash
python scripts/publish_github_release.py \
  --owner LanceLeeA \
  --repo router-plugin-hub \
  --tag ssrplus-enhanced-20260404v4 \
  --title "SSR Plus+ Enhanced 20260404v4" \
  --body-file docs/releases/ssrplus-enhanced-20260404v4-release-draft.md \
  --asset "C:/path/to/package.run" \
  --asset "C:/path/to/SHA256SUMS.txt" \
  --asset "C:/path/to/README.md"
```

执行前请先设置 `GITHUB_TOKEN` 环境变量。
