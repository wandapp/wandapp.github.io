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
- `macos.url`：直接指向 `wandapp/wandapp.github.io` GitHub Release 的 `Wand-macOS-arm64.dmg`。打开后把 Wand 拖到应用程序文件夹。
- `macos.version` / `build` / `requirements` / `notice`：正式版版本、构建号、系统要求、公证状态。
- `beta.available` / `version` / `build` / `url`：独立 Beta 通道，没有 Beta 时只保留 `{"available": false}`；URL 固定到 `macos-v<版本>-b<构建号>/Wand-macOS-arm64.dmg`。Beta 使用 Developer ID 签名、未经 Apple 公证，发布到 GitHub prerelease；官网只在文件公开且可校验后启用这个下载。
- App 默认读取 `macos`；用户在「设置 → 更新」开启「接收 Beta 更新」后读取 `beta`。同版本比较数字构建号，关闭 Beta 不自动降级。
- `installer.available`：统一安装器及其宣称支持的平台产物均通过验证后改为 true。
- `installer.command`：`curl -fsSL https://wandapp.github.io/install.sh | sh`。
- `installer.platforms` / `description`：已经验证的平台范围和自动安装行为；未验收 Linux 前不要列出 Linux。

首屏提供下载 App 与一条 curl 命令两种入口。macOS 安装完整 App，登录后自动启动；服务器安装器负责系统服务，无需用户另行安装 Core 或运行 start。内部模块仍可独立发布，这不构成用户安装步骤。

安装脚本由本仓库维护，构建时进入 `dist/`：

- `install.sh`：按系统转发到下面两个脚本。
- `install-macos.sh`：运行时读取线上 `release.json`（`macos.available`、`version`、`url`），不写死版本；URL 必须是 `macos-v<版本>/Wand-macOS-arm64.dmg` 形状，并保留 sha256、签名要求、spctl、Bundle ID、版本核对与备份回滚。`WAND_RELEASE_URL` 可覆盖 release.json 位置（仅测试；file:// 只经此变量接受），`WAND_PRINT_PLAN=1` 只打印解析结果。
- `install-linux.sh`：读取 `core/stable/manifest.json`，按架构取 `core.artifacts["linux-x64"|"linux-arm64"]`，校验 sha256 与大小后运行包内 `install.sh`（systemd 服务 `wand-core-sessiond` / `wand-core-gatewayd`，前缀 `/opt/wand-core`）。该平台尚未发布时直接失败且不改动系统。首次安装前无法验证清单签名（信任公钥在包内），依赖 HTTPS 与清单中的 sha256；之后的更新由已安装的 updater 验签。`WAND_PORT` 指定端口（默认 3210），`WAND_SERVICE_USER` 指定服务用户（默认调用者）。发现旧版 `/opt/wand` 或 `wand-scheduler` 时不改动，只提示端口冲突。`WAND_MANIFEST_URL`、`WAND_PLATFORM`、`WAND_PRINT_PLAN=1` 仅用于测试。

版本不再写进脚本；发布只需更新 `release.json` 与 `core/<通道>/manifest.json`。官网不提供 iOS 安装入口。未发布、读取失败或脚本禁用时提供 GitHub Releases 作为替代入口。

本页终端是标明“连接示意”的虚构示例，没有使用私密会话截图。品牌 SVG 复制自项目 `frontend/src/brand-mark.svg`，保持同源轮廓。
