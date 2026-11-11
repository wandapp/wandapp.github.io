import { channels, copyCommand } from "./release.js";

const byId = (id) => document.getElementById(id);
const install = byId("install");
const code = byId("install-command");
const status = byId("copy-status");
const copy = byId("copy-install");
const download = byId("download");
const tabs = [...document.querySelectorAll("[data-channel-option]")];

let channel = "stable";

function select(next, focus = false) {
  channel = next;
  const c = channels[next];
  install.dataset.channel = next;
  history.replaceState(null, "", next === "beta" ? "#beta" : location.pathname + location.search);
  code.replaceChildren(
    ...c.command.split(" ").flatMap((word, i) => [
      ...(i ? [" "] : []),
      Object.assign(document.createElement("span"), { textContent: word }),
    ]),
  );
  download.href = c.download;
  status.textContent = c.note;
  for (const tab of tabs) {
    const on = tab.dataset.channelOption === next;
    tab.setAttribute("aria-checked", String(on));
    tab.tabIndex = on ? 0 : -1;
    if (on && focus) tab.focus();
  }
}

for (const tab of tabs) {
  tab.addEventListener("click", () => select(tab.dataset.channelOption));
  tab.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    select(channel === "stable" ? "beta" : "stable", true);
  });
}

copy.addEventListener("click", async () => {
  if (copy.disabled) return;
  copy.disabled = true;
  copy.setAttribute("aria-busy", "true");
  try {
    await copyCommand(code.textContent);
    copy.dataset.state = "done";
    status.textContent = "已复制，在终端粘贴运行。";
    setTimeout(() => {
      delete copy.dataset.state;
      status.textContent = channels[channel].note;
    }, 2400);
  } catch {
    const range = document.createRange();
    range.selectNodeContents(code);
    const selection = window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    status.textContent = "无法访问剪贴板。命令已选中，请按 ⌘C 或 Ctrl+C 复制。";
  } finally {
    copy.disabled = false;
    copy.removeAttribute("aria-busy");
  }
});

// `#beta` links straight to the Beta command.
select(location.hash === "#beta" ? "beta" : "stable");
