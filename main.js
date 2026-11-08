import {
  releasesURL,
  validateRelease,
  copyCommand,
  appInstallCommand,
} from "./release.js";

const byId = (id) => document.getElementById(id);
const download = byId("download");
const status = byId("release-status");
const feedback = byId("copy-status");
const appFeedback = byId("app-copy-status");
const appCopy = byId("copy-app-install");
byId("app-install-command").textContent = appInstallCommand;
const coreCopies = [
  [byId("copy-install"), byId("install-command")],
  [byId("copy-start"), byId("start-command")],
];

const copies = [
  ...coreCopies.map(([button, code]) => [button, code, feedback]),
  [appCopy, byId("app-install-command"), appFeedback],
];

for (const [button, code, copyFeedback] of copies) {
  button.addEventListener("click", async () => {
    if (button.disabled) return;
    button.disabled = true;
    button.setAttribute("aria-busy", "true");
    try {
      await copyCommand(code.textContent);
      copyFeedback.textContent = "已复制。在终端中粘贴并运行。";
    } catch {
      const range = document.createRange();
      range.selectNodeContents(code);
      const selection = window.getSelection();
      selection?.removeAllRanges();
      selection?.addRange(range);
      copyFeedback.textContent =
        "无法访问剪贴板。命令已选中，请按 ⌘C 或 Ctrl+C 复制。";
    } finally {
      button.disabled = false;
      button.removeAttribute("aria-busy");
    }
  });
}

async function loadRelease() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch("./release.json", {
      signal: controller.signal,
      cache: "no-cache",
    });
    if (!response.ok) throw new Error("Release unavailable");
    const { macos, core } = validateRelease(await response.json());
    byId("requirements").textContent = macos.requirements;
    byId("core-platforms").textContent = core.platforms;
    if (macos.available) {
      download.href = macos.url;
      byId("download-label").textContent = "下载 macOS 客户端";
      status.textContent = `v${macos.version} · ${macos.notice}`;
      appCopy.disabled = false;
      appFeedback.textContent = `macOS v${macos.version} · 从 GitHub Releases 下载。`;
    } else {
      download.href = releasesURL;
      status.textContent = "macOS 客户端尚未发布，可前往版本页查看。";
      appFeedback.textContent = "macOS 客户端尚未发布，请稍后查看。";
    }
    if (core.available) {
      coreCopies.forEach(([button]) => {
        button.disabled = false;
      });
      feedback.textContent = `Core v${core.version} · 安装后不会自动启动。`;
    } else feedback.textContent = "Core 安装包尚未发布，请稍后查看。";
  } catch {
    status.textContent = "暂时无法读取版本，请到 GitHub Releases 查看。";
    feedback.textContent = "未能确认安装版本。请刷新页面，或查看版本记录。";
    appFeedback.textContent = feedback.textContent;
  } finally {
    clearTimeout(timer);
  }
}
loadRelease();
