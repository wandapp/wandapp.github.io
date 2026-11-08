# Wand 官网

独立静态官网：https://wandapp.github.io 。无框架、无运行时依赖，不连接用户的 Core、不读取登录信息。

## 本地开发

Node 22+：

```sh
npm run check
npm test
npm run build
python3 -m http.server 4173 --directory dist --bind 127.0.0.1
```

## 发布

GitHub Pages 使用 `.github/workflows/pages.yml`，从 `main` 构建发布。Pages 的 Source 设为 GitHub Actions。该设置与仓库公开权限由项目发布流程管理。

`release.json` 是唯一发布事实来源：

- `macos.available`：验过真实 GitHub Release 文件后改为 true。
- `macos.url`：直接指向 `wandapp/wandapp.github.io` GitHub Release 的 `Wand-macOS-arm64.zip`。
- `macos.version` / `requirements` / `notice`：版本、系统要求、签名状态。
- `core.available`：实际公开安装器与 Core 产物可用后改为 true。
- `core.command`：`curl -fsSL https://wandapp.github.io/install.sh | sh`。
- `core.startCommand`：`~/.local/bin/wand-core start`。
- `core.version` / `platforms`：实际支持范围。

根项目分发流程负责同步 `install.sh`。Core 可用时构建会检查安装器存在。未发布、读取失败、脚本禁用时不会给出虚假的下载成功状态：GitHub Releases 是始终可见的替代入口。

本页终端是标明“连接示意”的虚构示例，没有使用私密会话截图。品牌 SVG 复制自项目 `frontend/src/brand-mark.svg`，保持同源轮廓。
