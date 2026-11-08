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
