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
- `installer.available`：统一安装器及其宣称支持的平台产物均通过验证后改为 true。
- `installer.command`：`curl -fsSL https://wandapp.github.io/install.sh | sh`。
- `installer.platforms` / `description`：已经验证的平台范围和自动安装行为；未验收 Linux 前不要列出 Linux。

首屏提供下载 App 与一条 curl 命令两种入口。macOS 安装完整 App，登录后自动启动；服务器安装器负责系统服务，无需用户另行安装 Core 或运行 start。内部模块仍可独立发布，这不构成用户安装步骤。

根项目分发流程负责同步 `install.sh`、`install-macos.sh`、`install-linux.sh`。统一安装可用时构建检查入口安装器存在，平台脚本存在时进入部署白名单。下载与统一安装状态独立控制。未发布、读取失败或脚本禁用时提供 GitHub Releases 作为替代入口。

本页终端是标明“连接示意”的虚构示例，没有使用私密会话截图。品牌 SVG 复制自项目 `frontend/src/brand-mark.svg`，保持同源轮廓。
