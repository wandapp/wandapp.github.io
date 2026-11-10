import { copyCommand } from "./release.js";

const byId = (id) => document.getElementById(id);
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
