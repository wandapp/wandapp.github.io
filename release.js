export const releasesURL =
  "https://github.com/wandapp/wandapp.github.io/releases";
export const installCommand =
  "curl -fsSL https://wandapp.github.io/install.sh | sh";
export const startCommand = "~/.local/bin/wand-core start";

export function validateRelease(value) {
  if (
    !value ||
    value.schema !== 1 ||
    typeof value.macos?.available !== "boolean" ||
    typeof value.core?.available !== "boolean"
  )
    throw new Error("Invalid release manifest");
  const { macos, core } = value;
  const version = /^\d+\.\d+\.\d+(?:[-+][\w.-]+)?$/;
  if (!version.test(macos.version) || !version.test(core.version))
    throw new Error("Invalid version");
  const url = new URL(macos.url);
  if (
    url.origin !== "https://github.com" ||
    !url.pathname.startsWith("/wandapp/wandapp.github.io/releases/") ||
    !url.pathname.endsWith("/Wand-macOS-arm64.zip") ||
    url.search ||
    url.hash
  )
    throw new Error("Invalid download URL");
  for (const text of [macos.requirements, macos.notice, core.platforms])
    if (typeof text !== "string" || !text.trim() || text.length > 180)
      throw new Error("Invalid release text");
  if (core.command !== installCommand || core.startCommand !== startCommand)
    throw new Error("Unexpected installer command");
  return value;
}

export async function copyCommand(
  text,
  clipboard = globalThis.navigator?.clipboard,
) {
  if (!clipboard?.writeText) throw new Error("Clipboard unavailable");
  await clipboard.writeText(text);
}
