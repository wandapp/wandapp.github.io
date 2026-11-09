import { releasesURL, validateRelease, copyCommand } from "./release.js";

const byId = (id) => document.getElementById(id);
const download = byId("download");
const status = byId("release-status");
const feedback = byId("copy-status");
const installCopy = byId("copy-install");
const copies = [[installCopy, byId("install-command"), feedback]];

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
    const { macos, installer, beta } = validateRelease(await response.json());
    byId("requirements").textContent = macos.requirements;
    byId("installer-platforms").textContent = installer.platforms;
    byId("installer-description").textContent = installer.description;
    const betaLink = byId("beta-download");
    byId("beta-channel").hidden = !beta?.available;
    if (beta?.available) {
      betaLink.href = beta.url;
      byId("beta-status").textContent = `${beta.version} (${beta.build}) · 未经 Apple 公证`;
    }
    if (macos.available) {
      download.href = macos.url;
      byId("download-label").textContent = "下载正式版";
      status.textContent = `v${macos.version} · ${macos.notice}`;
    } else {
      download.href = releasesURL;
      status.textContent = "macOS 客户端尚未发布，可前往版本页查看。";
    }
    installCopy.disabled = !installer.available;
    feedback.textContent = installer.available
      ? "在终端运行，安装程序会自动完成配置与启动。"
      : "安装包尚未发布，请稍后查看。";
  } catch {
    status.textContent = "暂时无法读取版本，请到 GitHub Releases 查看。";
    feedback.textContent = "未能确认安装版本。请刷新页面，或查看版本记录。";
  } finally {
    clearTimeout(timer);
  }
}
loadRelease();
