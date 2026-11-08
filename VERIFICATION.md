# 官网验证

2026-11-08。网页实现验收通过；真实公开发布、Release 下载和 curl 安装由根项目分发任务验证，本仓库不将未发布状态视为分发通过。

- `npm run check` 通过；`npm test` 3/3 通过；`npm run build` 通过。
- Ego Browser，本地 `127.0.0.1:4173`：1440px 与390px全页检查，无横向溢出，命令完整换行、操作可达。截图在本机 `.impeccable/review/desktop-final.png`、`mobile-final.png`。
- 已发布清单通过浏览器请求替身验证：按钮直接使用约定 GitHub Release asset URL，启用两个命令复制；替身未改发布清单，不能当成实际可下载证据。
- 原生 Clipboard 写入确认“已复制”；模拟拒绝后显示恢复提示并选中准确命令，未伪报复制成功。
- 版本清单请求失败时保留 Releases 链接、禁用复制；未发布清单同样不提供虚假下载。
- 原生 details 通过键盘 Enter 展开，焦点保留在 summary；reduced-motion 下 smooth scroll 关闭。
- Premium strict audit 0 findings。Impeccable detector 3条仅限终端示意的缩小文字与模拟窗口的chrome边缘，由独立审阅判定非阻塞；它不是实际可交互工作台。
- 独立审阅要求删除页脚标语，已删除并重新截图。无私密数据、外部字体、第三方脚本或分析追踪。

GitHub Pages workflow参照[官方自定义工作流](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)，构建只复制允许公开的静态文件到dist，安装器存在时一起复制；不会上传设计记录、Git数据或测试证据。

## 客户端终端安装入口

2026-11-08：通过。将“下载与更新”移到macOS下载按钮附近，加入`install-app.sh`命令、目标目录及不自动启动说明。复用同一复制事件处理器，各区域有就近的固定高度状态。

- `npm run check`、4/4测试和静态构建通过。
- 浏览器请求替身仅把macOS设为可用、Core保持不可用，客户端复制已启用，Core复制仍禁用。
- 客户端命令原生剪贴板写入成功；拒绝路径选中完整准确的`install-app.sh`命令，提供手动复制提示。
- 未发布时客户端按钮禁用；“下载与更新”可由键盘Enter展开。
- 展开状态1440px/390px均无横向溢出，截图在`.impeccable/review/app-install-desktop.png`与`app-install-mobile.png`。
- 未修改发布清单状态及任何安装器；实际脚本下载与执行由根分发任务验收。

## 2026-11-08 — 统一自动安装入口（替代此前两步 Core 安装）

通过：`npm run check`、4 项 `npm test`、`npm run build`。首屏只保留 macOS App 下载和 `curl -fsSL https://wandapp.github.io/install.sh | sh`；没有 Core 前置、第二条安装脚本或手动 start。

Ego 浏览器实际检查通过：1440 桌面和 390 窄屏无横向溢出；发布关闭时复制禁用；注入可用 manifest 后下载直达约定 GitHub Release 资产，真实点击复制成功；剪贴板拒绝时明确失败并选中完整命令；Enter 展开远程连接说明；版本请求失败时禁用复制并给出替代版本页。TaskSpace 40 已结束。

这是官网交互验收，不代表安装产物、公证或服务器自动启动通过。macOS 与 installer 的实际发布状态仍为 false，Linux 未宣称可用；根分发任务验收后更新 manifest。此次尝试派发独立复核受 agent thread limit 阻挡，未取得新的独立复核结论。
