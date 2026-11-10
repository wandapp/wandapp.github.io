// Everything the page needs is a fixed address: GitHub's latest-release redirect always names the
// current stable dmg, so a release needs no edit here. (Release assets send no CORS headers, so the
// page cannot read the version at run time and does not show one.)
export const releasesURL = "https://github.com/wandapp/app/releases";
export const downloadURL =
  "https://github.com/wandapp/app/releases/latest/download/Wand-macOS-arm64.dmg";
export const installCommand =
  "curl -fsSL https://wandapp.github.io/install.sh | sh";

export async function copyCommand(
  text,
  clipboard = globalThis.navigator?.clipboard,
) {
  if (!clipboard?.writeText) throw new Error("Clipboard unavailable");
  await clipboard.writeText(text);
}
