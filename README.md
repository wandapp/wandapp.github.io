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

`.github/workflows/test.yml` 在推送和 PR 上跑检查、测试与构建；GitHub Pages 使用 `pages.yml`，从 `main` 构建发布。Pages 的 Source 设为 GitHub Actions。该设置与仓库公开权限由项目发布流程管理。

下载按钮固定指向 `https://github.com/wandapp/app/releases/latest/download/Wand-macOS-arm64.dmg`，页面不读取任何发布清单，发布不需要改本仓库。GitHub 的 Release 资产不带 CORS 头，页面无法在浏览器里读版本号，所以不显示版本。

发布物在公开仓库 `wandapp/app`（App）和 `wandapp/core`（Core、网页），流程见根仓库 `release/README.md`。本站不再托管更新源。

`release.json` 与 `core/<通道>/manifest.json(.sig)` 是旧版桥接文件：已安装的 0.4.x App 和主机仍读取它们，构建时原样复制进 `dist/`，页面不使用；只在发桥接版本时更新。

首屏提供下载 App 与一条 curl 命令两种入口：`curl -fsSL https://wandapp.github.io/install.sh | sh`。macOS 安装完整 App，登录后自动启动；服务器安装器负责系统服务，无需用户另行安装 Core 或运行 start。

安装脚本由本仓库维护，构建时进入 `dist/`：

- `install.sh`：按系统转发到下面两个脚本。
- `install-macos.sh`：运行时读取 `https://github.com/wandapp/app/releases/latest/download/release.json`（schema 2：`version`、`url`、`sha256`、`notarized`），不写死版本；要求 `notarized` 为 true，URL 必须是 `https://github.com/wandapp/app/releases/download/v<版本>/Wand-macOS-arm64.dmg` 形状，dmg 按 `sha256` 校验，并保留签名要求、spctl、Bundle ID、版本核对与备份回滚。`WAND_RELEASE_URL` 可覆盖 release.json 位置（仅测试；file:// 只经此变量接受），`WAND_PRINT_PLAN=1` 只打印解析结果。
- `install-linux.sh`：读取 `https://github.com/wandapp/core/releases/latest/download/manifest.json`，地址必须是 `https://github.com/wandapp/core/releases/download/v<版本>/wand-core-<版本>-<平台>.tar.gz` 形状，按架构取 `core.artifacts["linux-x64"|"linux-arm64"]`，校验 sha256 与大小后运行包内 `install.sh`（systemd 服务 `wand-core-sessiond` / `wand-core-gatewayd`，前缀 `/opt/wand-core`）。该平台尚未发布时直接失败且不改动系统。首次安装前无法验证清单签名（信任公钥在包内），依赖 HTTPS 与清单中的 sha256；之后的更新由已安装的 updater 验签。`WAND_PORT` 指定端口（默认 3210），`WAND_SERVICE_USER` 指定服务用户（默认调用者）。发现旧版 `/opt/wand` 或 `wand-scheduler` 时不改动，只提示端口冲突。`WAND_MANIFEST_URL`、`WAND_PLATFORM`、`WAND_PRINT_PLAN=1` 仅用于测试。

版本不再写进脚本，也不写进页面。官网不提供 iOS 安装入口。未发布、读取失败或脚本禁用时提供 GitHub Releases 作为替代入口。

本页终端是标明“连接示意”的虚构示例，没有使用私密会话截图。品牌 SVG 复制自项目 `frontend/src/brand-mark.svg`，保持同源轮廓。
