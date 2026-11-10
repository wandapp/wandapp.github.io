export const releasesURL =
  "https://github.com/wandapp/wandapp.github.io/releases";
export const installCommand =
  "curl -fsSL https://wandapp.github.io/install.sh | sh";
export function validateRelease(value) {
  if (
    !value ||
    value.schema !== 1 ||
    typeof value.macos?.available !== "boolean" ||
    typeof value.installer?.available !== "boolean"
  )
    throw new Error("Invalid release manifest");
  const { macos, installer, beta } = value;
  const version = /^(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})$/;
  if (!version.test(macos.version))
    throw new Error("Invalid version");
  assertAsset(macos.url, `macos-v${macos.version}`, ["Wand-macOS-arm64.dmg", "Wand-macOS-arm64.zip"]);
  if (macos.build != null && (!Number.isSafeInteger(macos.build) || macos.build < 1))
    throw new Error("Invalid stable build");
  if (beta != null) {
    if (typeof beta.available !== "boolean") throw new Error("Invalid beta channel");
    if (beta.available) {
      if (!version.test(beta.version) || !Number.isSafeInteger(beta.build) || beta.build < 1)
        throw new Error("Invalid beta version");
      assertAsset(beta.url, `macos-v${beta.version}-b${beta.build}`, ["Wand-macOS-arm64.dmg"]);
    }
  }
  for (const text of [macos.requirements, macos.notice, installer.platforms, installer.description])
    if (typeof text !== "string" || !text.trim() || text.length > 180)
      throw new Error("Invalid release text");
  if (installer.command !== installCommand)
    throw new Error("Unexpected installer command");
  return value;
}

function assertAsset(value, tag, names) {
  const url = new URL(value);
  const name = url.pathname.split("/").pop();
  if (
    url.origin !== "https://github.com" ||
    url.username || url.password ||
    url.pathname !== `/wandapp/wandapp.github.io/releases/download/${tag}/${name}` ||
    !names.includes(name) ||
    url.search ||
    url.hash
  )
    throw new Error("Invalid download URL");
}

export async function copyCommand(
  text,
  clipboard = globalThis.navigator?.clipboard,
) {
  if (!clipboard?.writeText) throw new Error("Clipboard unavailable");
  await clipboard.writeText(text);
}

// A Beta is only advertised while it is newer than the stable release, by (version, build).
export function betaIsNewer(macos, beta) {
  if (!beta?.available) return false;
  const key = (r) => [...r.version.split(".").map(Number), r.build ?? 0];
  const [a, b] = [key(beta), key(macos)];
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] > b[i];
  return false;
}
