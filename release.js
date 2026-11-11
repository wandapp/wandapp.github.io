// Everything the page needs is a fixed address: GitHub's latest-release redirect always names the
// current stable dmg and the `beta` release always carries the newest build, so a release needs no
// edit here. (Release assets send no CORS headers, so the page cannot read the version at run time
// and does not show one.)
export const releasesURL = "https://github.com/wandapp/app/releases";
export const downloadURL =
  "https://github.com/wandapp/app/releases/latest/download/Wand-macOS-arm64.dmg";
export const betaDownloadURL =
  "https://github.com/wandapp/app/releases/download/beta/Wand-macOS-arm64.dmg";
export const installCommand =
  "curl -fsSL https://wandapp.github.io/install.sh | sh";
export const betaInstallCommand =
  "curl -fsSL https://wandapp.github.io/install.sh | sh -s -- --beta";

export const channels = {
  stable: {
    command: installCommand,
    download: downloadURL,
    note: "Mac 上安装 App 与后台服务，Linux 上安装服务；已安装的直接升级到最新正式版。",
  },
  beta: {
    command: betaInstallCommand,
    download: betaDownloadURL,
    note: "安装或升级到最新构建，之后自动更新也走 Beta。App 已签名，可能未经 Apple 公证。",
  },
};

export async function copyCommand(
  text,
  clipboard = globalThis.navigator?.clipboard,
) {
  if (!clipboard?.writeText) throw new Error("Clipboard unavailable");
  await clipboard.writeText(text);
}
